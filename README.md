# TWRP device tree for OPLUS SM87xx series

## 说明（本 fork 变更）

本仓库基于 [kmiit/twrp_device_oplus_sm87xx](https://github.com/kmiit/twrp_device_oplus_sm87xx)（`twrp-16.0`，`74d0756`），在其上完成并**真机验证**了 OnePlus 13T / pagani 适配，适用于 **Android 15 `.302`（ColorOS 15）** 固件基线。

### 适用设备（本 fork 已实机验证）

| 设备 | 型号 | Android device | codename | project | 验证状态 |
|---|---|---|---|---|---|
| **OnePlus 13T (CN)** | PKX110 | OP60F5L1 | pagani | 24821 | ✅ 完整验证（见下） |
| OnePlus 13s (IN) | CPH2723 | OP612BL1 | pagani | 24875 | 未实机验证（同一 platform，理论支持） |
| 其他上游支持机型（13/Ace5Pro/Ace6/Turbo6/GK7Pro/GK8/Pad2Pro 等） | — | — | — | — | 继承上游，路径未改动，未验证 |

### 本 fork 修复/变更内容

1. **Super 分区几何修正**
   - 上游硬编码 `BOARD_SUPER_PARTITION_SIZE=15569256448`，比 pagani 实机（`14,956,888,064`）大 `612,368,384` 字节。
   - 已改为实机值：`14956888064` / `BOARD_QTI_DYNAMIC_PARTITIONS_SIZE=14952693760`（依据真机 `lpdump` 与 fastboot `getvar` 双重确认）。

2. **pagani 24821 触控资产**
   - 上游仅含 ktm（Ace6）与 vw（Turbo6）触控固件；本 fork 加入 PKX110 实测面板（`synaptics-s3910`）所需的 **24821 / S3910 / TIANMA_HBP** 全套固件与配置（提取自已校验的 `.302` stock recovery），同时提供 `/vendor/firmware/tp/24821` 与 `/odm/firmware/tp/24821` 两条路径。
   - 实机触控正常（hbp5 launcher + 24821 固件链路）。

3. **移除冗余 touch-aidl-1 服务（崩溃循环修复）**
   - 早期提交的 `.302` touch 服务（`touch-service-pagani.sh` + `touch302/`）因 `/odm` 无对应符号链接而 `exit 127` 每 ~5s 崩溃重启，并与 hbp5 重复注册同一 AIDL 接口。
   - 已整体移除冗余链（保留 hbp5 链与 24821 固件），实机 dmesg 确认零崩溃、零重复注册。

4. **KeyMint 版本检测修复（位于 TWRP `bootable/recovery` fork）**
   - 设备为 AIDL-only 加密栈（`android.hardware.security.keymint` v3），上游只查 HIDL `keymaster` 且 manifest 文件名拼接错误 → 版本解析为空。
   - 修复：增加 KeyMint fallback；修复 `find` 输出尾随换行导致 `Path_Exists` 失败而静默跳过 manifest 片段的问题。
   - 实机日志确认：`Using keymaster version '3' for decryption`。
   - 对应 commit：`f93a56b`（需配合 TWRP-Test/android_bootable_recovery 的 `fix/pagani-keymint-detect` 分支）。

5. **最小 recovery crypto SELinux 策略**
   - 新增 `sepolicy/`（crypto 域类型、file_contexts、tee/keymint/gatekeeper/ssgtzd 域规则、recovery dm ioctl 等），通过 AOSP neverallow 检查（0 冲突），实机 crypto 类型不再 "left unmapped"。
   - 注意：TWRP 的 `recovery` 域在本树是 `coredomain`，AOSP neverallow 禁止其执行 vendor exec、注册 HAL/keystore 服务等；相关规则按约束省略并在 `sepolicy/*.te` 注释中说明。recovery 目前以 permissive 运行，功能不受影响。

### 实机验证记录（OnePlus 13T PKX110，Android 15 `.302`）

```text
Boot / Display / Touch          PASS
ADB / USB gadget                PASS
Bootconfig / Bootdevice         PASS（163 by-name 条目）
Partition enumeration           PASS（super 17 逻辑分区）
/data mount + FBE 解密（PIN）    PASS（wrappedkey_v0 + synthetic password + weaver）
MTP 枚举与只读浏览 / USB OTG      PASS
Reboot System/Recovery/Bootloader PASS（slot 全程不变）
```

未实测项目：MTP 写、Backup 执行、Sideload、Fastbootd、Enforcing 模式（按数据安全原则留待后续）。

## 构建

```shell
mkdir twrp && cd twrp
repo init --depth=1 -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git -b twrp-16.0
repo sync
git clone https://github.com/yankedi/twrp_device_oneplus13t device/oplus/sm87xx
```

KeyMint 检测修复需配套 TWRP recovery fork：

```shell
# bootable/recovery 使用含 fix/pagani-keymint-detect 的 fork（或等价 cherry-pick f93a56b）
```

```shell
source build/envsetup.sh
lunch twrp_sm87xx
make recoveryimage -j8
```

产物：`out/target/product/sm87xx/recovery.img`（104,857,600 字节，header v4，无 kernel，LZ4 ramdisk）。

## 刷入（仅建议在已解锁 bootloader 上操作）

**注意**：本镜像为 kernelless recovery（与原厂布局一致），不支持 `fastboot boot recovery.img` 临时启动（bootloader 拒绝 `Bad Buffer Size`）。正确安装方式为写入 recovery 分区：

```shell
fastboot flash recovery_b recovery.img   # 或 recovery_a；先备份原分区
fastboot reboot recovery
```

刷写前请备份原 recovery 与用户数据；解密失败、挂载异常时勿执行 format/wipe。测试期间推荐只写单侧 slot，保留另一侧原厂 recovery 作为回滚。

## Features

实机验证（OnePlus 13T）：

- [X] ADB / USB
- [X] Display / Touch
- [X] FBE 解密（metadata + PIN，`wrappedkey_v0`）
- [X] 分区枚举 / 动态分区（super 17 逻辑分区）
- [X] MTP（枚举与只读浏览）
- [X] USB OTG
- [X] Vibrator

上游声明、本 fork 未逐项实测：Flashing、Sideload、Fastbootd、Backup/Restore。
