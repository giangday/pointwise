# -*- coding: utf-8 -*-
"""
Full Pipeline: Baseline -> QAT (Q6.10) -> BN Fusion -> FPGA Memory (.mem) -> Golden Model Activations
"""

# %% [markdown]
# # CELL 0: SETUP (KHỞI TẠO)
# Import thư viện và định nghĩa Kiến trúc Baseline (Float32) & QAT Model (Q6.10)

# %%
import os
import time
import copy
import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import torchvision.transforms as transforms
from PIL import Image
import numpy as np
import matplotlib.pyplot as plt
from torchmetrics.image.psnr import PeakSignalNoiseRatio
from torchmetrics.image.ssim import StructuralSimilarityIndexMeasure

# ==========================================
# CẤU HÌNH ĐƯỜNG DẪN & THAM SỐ
# ==========================================
class Config:
    TRAIN_DIR = "./data/train/real" # THAY ĐỔI ĐƯỜNG DẪN NÀY
    VAL_DIR = "./data/valid/real"   # THAY ĐỔI ĐƯỜNG DẪN NÀY
    OUT_DIR = "./output_pipeline"
    
    IMG_SIZE = 128
    BATCH_SIZE = 32
    BASE_C = 16
    QAT_EPOCHS = 3 # Chỉ fine-tune ngắn
    LR = 1e-4
    DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    
    # Hàm tạo thư mục con
    @staticmethod
    def get_dir(sub_dir):
        path = os.path.join(Config.OUT_DIR, sub_dir)
        os.makedirs(path, exist_ok=True)
        return path

# ==========================================
# TOÁN TỬ LƯỢNG TỬ HÓA Q6.10
# ==========================================
class FakeQuantizeQ6_10(torch.autograd.Function):
    @staticmethod
    def forward(ctx, x):
        scale = 1024.0
        return torch.round(x * scale).clamp(-32768, 32767) / scale

    @staticmethod
    def backward(ctx, grad_output):
        return grad_output

def qat_quant(x):
    return FakeQuantizeQ6_10.apply(x)

class QuantIdentity(nn.Module):
    def forward(self, x): return qat_quant(x)

# Hàm hỗ trợ xuất Hex chuẩn Q6.10
def tensor_to_q6_10_hex(tensor, scale=1024.0):
    arr = torch.round(tensor.detach().cpu() * scale).clamp(-32768, 32767).to(torch.int16).numpy().flatten()
    return [f"{val & 0xFFFF:04x}" for val in arr]

def save_hex_lines(hex_lines, filepath):
    with open(filepath, "w") as f:
        f.write("\n".join(hex_lines) + "\n")

def export_model_weights_hex(model, out_dir, prefix=""):
    os.makedirs(out_dir, exist_ok=True)
    for name, tensor in model.state_dict().items():
        if "num_batches_tracked" in name: continue
        hex_lines = tensor_to_q6_10_hex(tensor)
        safe_name = name.replace(".", "_")
        save_hex_lines(hex_lines, os.path.join(out_dir, f"{prefix}{safe_name}.hex"))

# ==========================================
# KIẾN TRÚC BASELINE (FLOAT32)
# ==========================================
class SeparableConv2d(nn.Module):
    def __init__(self, in_channels, out_channels, kernel_size=3, stride=1, padding=1):
        super().__init__()
        self.depthwise = nn.Conv2d(in_channels, in_channels, kernel_size, stride, padding, groups=in_channels, bias=False)
        self.pointwise = nn.Conv2d(in_channels, out_channels, kernel_size=1, bias=False)
    def forward(self, x): return self.pointwise(self.depthwise(x))

class BaselineEncoder(nn.Module):
    def __init__(self, base_c=16):
        super().__init__()
        def conv_block(in_c, out_c, stride=1):
            return nn.Sequential(
                SeparableConv2d(in_c, out_c, stride=stride),
                nn.BatchNorm2d(out_c),
                nn.LeakyReLU(0.1, inplace=True))
        
        self.head = conv_block(6, base_c)
        self.down1 = conv_block(base_c, base_c*2, stride=2)
        self.down2 = conv_block(base_c*2, base_c*4, stride=2)
        self.down3 = conv_block(base_c*4, base_c*8, stride=2)
        self.bottleneck = conv_block(base_c*8, base_c*8, stride=2)
        self.upsample = nn.Upsample(scale_factor=2, mode='nearest')
        
        self.up1 = conv_block(base_c*8 + base_c*8, base_c*4)
        self.up2 = conv_block(base_c*4 + base_c*4, base_c*2)
        self.up3 = conv_block(base_c*2 + base_c*2, base_c)
        self.up4 = conv_block(base_c + base_c, base_c)
        self.tail = nn.Sequential(SeparableConv2d(base_c, 3, stride=1))

    def forward(self, x_cover, x_secret):
        x = torch.cat([x_cover, x_secret], dim=1)
        head = self.head(x); d1 = self.down1(head); d2 = self.down2(d1); d3 = self.down3(d2); b = self.bottleneck(d3)
        u1 = self.up1(torch.cat([self.upsample(b), d3], dim=1))
        u2 = self.up2(torch.cat([self.upsample(u1), d2], dim=1))
        u3 = self.up3(torch.cat([self.upsample(u2), d1], dim=1))
        u4 = self.up4(torch.cat([self.upsample(u3), head], dim=1))
        return torch.clamp(x_cover + self.tail(u4), -1, 1)

class BaselineDecoder(nn.Module):
    def __init__(self, base_c=16):
        super().__init__()
        def conv_block(in_c, out_c, stride=1):
            return nn.Sequential(
                nn.Conv2d(in_c, out_c, 3, stride, 1, bias=True),
                nn.BatchNorm2d(out_c),
                nn.LeakyReLU(0.1, inplace=True))
            
        self.head = conv_block(3, base_c)
        self.down1 = conv_block(base_c, base_c*2, stride=2)
        self.down2 = conv_block(base_c*2, base_c*4, stride=2)
        self.down3 = conv_block(base_c*4, base_c*8, stride=2)
        self.down4 = conv_block(base_c*8, base_c*16, stride=2)
        self.bottleneck = conv_block(base_c*16, base_c*16, stride=2)
        self.upsample = nn.Upsample(scale_factor=2, mode='bilinear', align_corners=True)
        
        self.up1 = conv_block(base_c*16 + base_c*16, base_c*8)
        self.up2 = conv_block(base_c*8 + base_c*8, base_c*4)
        self.up3 = conv_block(base_c*4 + base_c*4, base_c*2)
        self.up4 = conv_block(base_c*2 + base_c*2, base_c)
        self.up5 = conv_block(base_c + base_c, base_c)
        self.tail = nn.Sequential(nn.Conv2d(base_c, 3, 3, padding=1), nn.Tanh())

    def forward(self, x):
        c1 = self.head(x); c2 = self.down1(c1); c3 = self.down2(c2); c4 = self.down3(c3); c5 = self.down4(c4)
        b = self.bottleneck(c5)
        u1 = self.up1(torch.cat([self.upsample(b), c5], dim=1))
        u2 = self.up2(torch.cat([self.upsample(u1), c4], dim=1))
        u3 = self.up3(torch.cat([self.upsample(u2), c3], dim=1))
        u4 = self.up4(torch.cat([self.upsample(u3), c2], dim=1))
        u5 = self.up5(torch.cat([self.upsample(u4), c1], dim=1))
        return self.tail(u5)

# ==========================================
# KIẾN TRÚC QAT (Q6.10)
# ==========================================
class QATSeparableConv2d(nn.Module):
    def __init__(self, in_channels, out_channels, kernel_size=3, stride=1, padding=1):
        super().__init__()
        self.depthwise = nn.Conv2d(in_channels, in_channels, kernel_size, stride, padding, groups=in_channels, bias=False)
        self.pointwise = nn.Conv2d(in_channels, out_channels, kernel_size=1, bias=False)

    def forward(self, x):
        w_dw = qat_quant(self.depthwise.weight)
        w_pw = qat_quant(self.pointwise.weight)
        x = F.conv2d(x, w_dw, self.depthwise.bias, self.depthwise.stride, self.depthwise.padding, self.depthwise.dilation, self.depthwise.groups)
        x = qat_quant(x)
        x = F.conv2d(x, w_pw, self.pointwise.bias, self.pointwise.stride, self.pointwise.padding, self.pointwise.dilation, self.pointwise.groups)
        return x

class QATEncoder(nn.Module):
    def __init__(self, base_c=16):
        super().__init__()
        def qat_conv_block(in_c, out_c, stride=1):
            return nn.Sequential(
                QATSeparableConv2d(in_c, out_c, stride=stride),
                nn.BatchNorm2d(out_c),
                nn.LeakyReLU(0.1, inplace=True),
                QuantIdentity()
            )
        self.head = qat_conv_block(6, base_c)
        self.down1 = qat_conv_block(base_c, base_c*2, stride=2)
        self.down2 = qat_conv_block(base_c*2, base_c*4, stride=2)
        self.down3 = qat_conv_block(base_c*4, base_c*8, stride=2)
        self.bottleneck = qat_conv_block(base_c*8, base_c*8, stride=2)
        self.upsample = nn.Upsample(scale_factor=2, mode='nearest')
        
        self.up1 = qat_conv_block(base_c*8 + base_c*8, base_c*4)
        self.up2 = qat_conv_block(base_c*4 + base_c*4, base_c*2)
        self.up3 = qat_conv_block(base_c*2 + base_c*2, base_c)
        self.up4 = qat_conv_block(base_c + base_c, base_c)
        self.tail_dw = nn.Conv2d(base_c, base_c, 3, 1, 1, groups=base_c, bias=False)
        self.tail_pw = nn.Conv2d(base_c, 3, 1, bias=False)

    def forward(self, x_cover, x_secret):
        x_cover = qat_quant(x_cover); x_secret = qat_quant(x_secret)
        x = torch.cat([x_cover, x_secret], dim=1)
        head = self.head(x); d1 = self.down1(head); d2 = self.down2(d1); d3 = self.down3(d2); b = self.bottleneck(d3)
        u1 = self.up1(torch.cat([self.upsample(b), d3], dim=1))
        u2 = self.up2(torch.cat([self.upsample(u1), d2], dim=1))
        u3 = self.up3(torch.cat([self.upsample(u2), d1], dim=1))
        u4 = self.up4(torch.cat([self.upsample(u3), head], dim=1))
        
        # Tail manually quantized
        w_dw = qat_quant(self.tail_dw.weight); w_pw = qat_quant(self.tail_pw.weight)
        out = F.conv2d(u4, w_dw, None, 1, 1, 1, self.tail_dw.groups)
        out = qat_quant(out)
        out = F.conv2d(out, w_pw, None, 1, 0)
        out = qat_quant(out)
        
        return torch.clamp(x_cover + out, -1, 1)

print("✅ CELL 0: Khởi tạo xong!")


# %% [markdown]
# # CELL 1: ĐÁNH GIÁ BASELINE MODEL (FLOAT32)
# Load Weights, Test 1 ảnh, Xuất Hex Input/Output, Lưu Weights ra file, Đánh giá toàn dataset

# %%
class RealImageDataset(Dataset):
    def __init__(self, d_path, img_size=128):
        try: self.paths = [os.path.join(d_path, f) for f in os.listdir(d_path) if f.lower().endswith(('png','jpg','jpeg'))]
        except: self.paths = []
        self.t = transforms.Compose([transforms.Resize((img_size, img_size)), transforms.ToTensor(), transforms.Normalize([0.5]*3,[0.5]*3)])
    def __len__(self): return len(self.paths)
    def __getitem__(self, i): return self.t(Image.open(self.paths[i]).convert("RGB"))

def get_dataloader(path, cfg, shuffle=True):
    return DataLoader(RealImageDataset(path, cfg.IMG_SIZE), batch_size=cfg.BATCH_SIZE, shuffle=shuffle, drop_last=True)

def visualize_and_export_sample(enc, dec, loader, cfg, prefix, out_dir):
    enc.eval(); dec.eval()
    cover = next(iter(loader))[:1].to(cfg.DEVICE)
    secret = next(iter(loader))[1:2].to(cfg.DEVICE) # Lấy ảnh thứ 2 làm secret
    
    with torch.no_grad():
        stego = enc(cover, secret)
        recover = dec(stego)
        residual = torch.abs(stego - cover)
        residual = residual / (residual.max() + 1e-8)
    
    # --- Trực quan hóa ---
    imgs = [cover, secret, stego, residual, recover]
    titles = ["Cover", "Secret", "Stego", "Residual", "Recover"]
    fig, axes = plt.subplots(1, 5, figsize=(15, 3))
    for j in range(5):
        img_show = ((imgs[j].squeeze(0).cpu() + 1)/2).clamp(0,1).permute(1,2,0).numpy()
        if j == 3: img_show = img_show.mean(2)
        axes[j].imshow(img_show, cmap='inferno' if j==3 else None)
        axes[j].set_title(titles[j]); axes[j].axis('off')
    plt.savefig(os.path.join(out_dir, f"{prefix}_sample.png"))
    plt.show()
    
    # --- Xuất HEX In/Out ---
    save_hex_lines(tensor_to_q6_10_hex(cover), os.path.join(out_dir, f"{prefix}_input_cover.hex"))
    save_hex_lines(tensor_to_q6_10_hex(secret), os.path.join(out_dir, f"{prefix}_input_secret.hex"))
    save_hex_lines(tensor_to_q6_10_hex(stego), os.path.join(out_dir, f"{prefix}_output_stego.hex"))
    save_hex_lines(tensor_to_q6_10_hex(recover), os.path.join(out_dir, f"{prefix}_output_recover.hex"))
    
    return cover, secret # Trả về để dùng chung cho các Cell sau

def eval_dataset(enc, dec, loader, cfg, tag=""):
    enc.eval(); dec.eval()
    psnr_fn = PeakSignalNoiseRatio(data_range=1.0).to(cfg.DEVICE)
    ssim_fn = StructuralSimilarityIndexMeasure(data_range=1.0).to(cfg.DEVICE)
    p_c, s_c, p_s, s_s, count = 0, 0, 0, 0, 0
    
    with torch.no_grad():
        for cover in loader:
            cover = cover.to(cfg.DEVICE)
            secret = cover[torch.randperm(cover.size(0))].to(cfg.DEVICE)
            stego = enc(cover, secret)
            recover = dec(stego)
            
            c01 = ((cover+1)/2).clamp(0,1); st01 = ((stego+1)/2).clamp(0,1)
            se01 = ((secret+1)/2).clamp(0,1); re01 = ((recover+1)/2).clamp(0,1)
            
            p_c += psnr_fn(st01, c01).item(); s_c += ssim_fn(st01, c01).item()
            p_s += psnr_fn(re01, se01).item(); s_s += ssim_fn(re01, se01).item()
            count += 1
            if count >= 20: break # Giới hạn batch để demo nhanh, xóa break để chạy full
            
    print(f"[{tag}] COVER  - PSNR: {p_c/count:.2f} dB, SSIM: {s_c/count:.4f}")
    print(f"[{tag}] SECRET - PSNR: {p_s/count:.2f} dB, SSIM: {s_s/count:.4f}")

# Khởi tạo mô hình
cfg = Config()
val_loader = get_dataloader(cfg.VAL_DIR, cfg, shuffle=False)

enc_base = BaselineEncoder(cfg.BASE_C).to(cfg.DEVICE)
dec_base = BaselineDecoder(cfg.BASE_C).to(cfg.DEVICE)

# Giả lập Load Weights (Thực tế hãy truyền đúng đường dẫn pretrained)
# enc_base.load_state_dict(torch.load("path_to_best_enc.pth"))
print("✅ Khởi tạo & Load Baseline Model")

out_cell1 = cfg.get_dir("cell1_baseline")
sample_cover, sample_secret = visualize_and_export_sample(enc_base, dec_base, val_loader, cfg, "baseline", out_cell1)

# Lưu .pth và .hex cho Weight/BN
torch.save(enc_base.state_dict(), os.path.join(out_cell1, "baseline_enc.pth"))
export_model_weights_hex(enc_base, os.path.join(out_cell1, "hex_weights"), prefix="base_")

if len(val_loader) > 0:
    eval_dataset(enc_base, dec_base, val_loader, cfg, tag="BASELINE FLOAT32")
else:
    print("⚠ Thư mục Dataset trống, bỏ qua Eval Baseline.")


# %% [markdown]
# # CELL 2: FINE-TUNE QAT (Q6.10)
# Transfer weights từ Baseline -> Fine-tune ngắn hạn -> Đánh giá lại

# %%
enc_qat = QATEncoder(cfg.BASE_C).to(cfg.DEVICE)
dec_qat = BaselineDecoder(cfg.BASE_C).to(cfg.DEVICE) # Decoder ít nhạy cảm, giữ nguyên Float

# Load matched weights từ Baseline sang QAT
enc_qat.load_state_dict(enc_base.state_dict(), strict=False)
dec_qat.load_state_dict(dec_base.state_dict(), strict=False)

out_cell2 = cfg.get_dir("cell2_qat")
train_loader = get_dataloader(cfg.TRAIN_DIR, cfg, shuffle=True)

if len(train_loader) > 0:
    print(f"Bắt đầu Fine-tune QAT ({cfg.QAT_EPOCHS} epochs)...")
    opt = optim.Adam(list(enc_qat.parameters()) + list(dec_qat.parameters()), lr=cfg.LR)
    l1 = nn.L1Loss(); l2 = nn.MSELoss()
    
    for ep in range(1, cfg.QAT_EPOCHS + 1):
        enc_qat.train(); dec_qat.train()
        for idx, cover in enumerate(train_loader):
            cover = cover.to(cfg.DEVICE)
            secret = cover[torch.randperm(cover.size(0))].to(cfg.DEVICE)
            
            opt.zero_grad()
            stego = enc_qat(cover, secret)
            recover = dec_qat(stego)
            
            loss = (l1(stego, cover) + 0.5*l2(stego, cover)) + (l1(recover, secret) + 0.5*l2(recover, secret))
            loss.backward()
            opt.step()
            
            if idx % 50 == 0:
                print(f"  Ep {ep} - Batch {idx}: Loss = {loss.item():.4f}")
            if idx >= 100: break # Demo: chỉ train 100 batch mỗi epoch
else:
    print("⚠ Thư mục Train trống, bỏ qua quá trình Fine-tune.")

# Đánh giá và Xuất
print("Đánh giá sau QAT:")
_ = visualize_and_export_sample(enc_qat, dec_qat, val_loader, cfg, "qat", out_cell2)

if len(val_loader) > 0:
    eval_dataset(enc_qat, dec_qat, val_loader, cfg, tag="QAT Q6.10")

# Lưu Weight QAT
torch.save(enc_qat.state_dict(), os.path.join(out_cell2, "qat_enc.pth"))
export_model_weights_hex(enc_qat, os.path.join(out_cell2, "hex_weights"), prefix="qat_")


# %% [markdown]
# # CELL 3: FUSE BATCHNORM
# Ép BatchNorm vào Pointwise Convolution để loại bỏ BN khi chạy trên FPGA

# %%
def fuse_conv_bn_weights(conv, bn):
    with torch.no_grad():
        mean, var_sqrt = bn.running_mean, torch.sqrt(bn.running_var + bn.eps)
        gamma, beta = bn.weight, bn.bias
        w_conv = conv.weight.clone()
        b_conv = conv.bias.clone() if conv.bias is not None else torch.zeros_like(mean)
        scale = (gamma / var_sqrt).view(-1, 1, 1, 1)
        return w_conv * scale, beta + (b_conv - mean) * (gamma / var_sqrt)

def fuse_qat_model(model):
    print(">>> Đang Fuse BN vào Conv...")
    fused_model = copy.deepcopy(model).eval()
    for m in fused_model.modules():
        if isinstance(m, nn.Sequential) and len(m) >= 2:
            if isinstance(m[0], QATSeparableConv2d) and isinstance(m[1], nn.BatchNorm2d):
                fw, fb = fuse_conv_bn_weights(m[0].pointwise, m[1])
                m[0].pointwise = nn.Conv2d(m[0].pointwise.in_channels, m[0].pointwise.out_channels, 1, bias=True)
                m[0].pointwise.weight.data.copy_(fw)
                m[0].pointwise.bias.data.copy_(fb)
                m[1] = nn.Identity() # Bỏ BN
    return fused_model

out_cell3 = cfg.get_dir("cell3_fused")
enc_fused = fuse_qat_model(enc_qat)

print("Trực quan hóa Fused Model:")
_ = visualize_and_export_sample(enc_fused, dec_qat, val_loader, cfg, "fused", out_cell3)

# Đo lường sai lệch MAE
print("So sánh độ lệch giữa QAT và Fused Model (tối đa 1000 ảnh)...")
enc_qat.eval(); enc_fused.eval()
mae_sum = 0; count = 0; all_close = True

with torch.no_grad():
    for cover in val_loader:
        cover = cover.to(cfg.DEVICE)
        secret = cover[torch.randperm(cover.size(0))].to(cfg.DEVICE)
        
        out_qat = enc_qat(cover, secret)
        out_fus = enc_fused(cover, secret)
        
        mae_sum += torch.abs(out_qat - out_fus).mean().item()
        if not torch.allclose(out_qat, out_fus, atol=1e-5):
            all_close = False
        count += 1
        if count * cfg.BATCH_SIZE >= 1000: break

if count > 0:
    print(f"MAE giữa QAT và Fused: {mae_sum/count:.8f}")
    print(f"All Close (atol=1e-5)? {'CÓ (Thành công)' if all_close else 'KHÔNG (Có sai số nhỏ)'}")


# %% [markdown]
# # CELL 4: XUẤT MEMORY FILE (.MEM) CHO FPGA
# Tách riêng trọng số Depthwise và Pointwise ra 2 file .mem để nạp bộ nhớ

# %%
out_cell4 = cfg.get_dir("cell4_mem")

def export_mem_files(model, out_dir):
    dw_path = os.path.join(out_dir, "depthwise.mem")
    pw_path = os.path.join(out_dir, "pointwise.mem")
    
    with open(dw_path, "w") as f_dw, open(pw_path, "w") as f_pw:
        for name, module in model.named_modules():
            # DEPTHWISE
            if isinstance(module, nn.Conv2d) and module.groups > 1:
                hex_data = tensor_to_q6_10_hex(module.weight)
                f_dw.write('\n'.join(hex_data) + '\n')
            
            # POINTWISE (Kernel 1x1)
            elif isinstance(module, nn.Conv2d) and module.kernel_size == (1, 1):
                w_hex = tensor_to_q6_10_hex(module.weight)
                f_pw.write('\n'.join(w_hex) + '\n')
                if module.bias is not None:
                    b_hex = tensor_to_q6_10_hex(module.bias)
                    f_pw.write('\n'.join(b_hex) + '\n')

export_mem_files(enc_fused.cpu(), out_cell4) # Dùng CPU để xuất mem
enc_fused.to(cfg.DEVICE) # Trả lại device cũ
print(f"✅ Đã xuất depthwise.mem và pointwise.mem tại {out_cell4}")


# %% [markdown]
# # CELL 5: XUẤT GOLDEN MODEL (ACTIVATIONS)
# Lấy Activation trung gian bằng Hooks để làm Testbench so sánh với Verilog

# %%
out_cell5 = cfg.get_dir("cell5_golden")

def get_golden_activations(model, cover, secret, out_dir):
    layer_outputs = {}
    
    # Hàm Hook
    def hook_fn(name):
        def hook(module, input, output):
            layer_outputs[name] = output.detach().cpu()
        return hook

    # Đăng ký Hook vào các lớp chính
    hooks = []
    target_classes = ['QATSeparableConv2d', 'Conv2d', 'QuantIdentity', 'Upsample']
    for name, module in model.named_modules():
        if module.__class__.__name__ in target_classes:
            safe_name = name.replace('.', '_')
            hooks.append(module.register_forward_hook(hook_fn(safe_name)))
            
    print(f"Đã đăng ký {len(hooks)} Hooks. Tiến hành chạy 1 Sample...")
    
    # Chạy Model
    model.eval()
    with torch.no_grad():
        stego_out = model(cover, secret)
        
    # Gỡ Hooks
    for h in hooks: h.remove()
        
    # Lưu Hex cho từng layer
    os.makedirs(os.path.join(out_dir, "activations"), exist_ok=True)
    for name, output in layer_outputs.items():
        hex_lines = tensor_to_q6_10_hex(output)
        save_hex_lines(hex_lines, os.path.join(out_dir, "activations", f"{name}_out.hex"))
        
    print(f"✅ Đã lưu {len(layer_outputs)} file activations (.hex) vào {out_dir}/activations")

# Lấy lại sample dùng từ Cell 1
get_golden_activations(enc_fused, sample_cover, sample_secret, out_cell5)
print("🎉 TOÀN BỘ QUY TRÌNH ĐÃ HOÀN TẤT!")