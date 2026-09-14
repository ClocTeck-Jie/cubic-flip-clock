# Cubic 翻页时钟 1.2.1

为 HoloCubic 320×240 小屏制作的 Lua 翻页时钟，提供独立天气、网页设置和手柄支持。

原项目由 **[baby-watch](https://github.com/baby-watch)** 发布：[baby-watch/cubic-flip-clock](https://github.com/baby-watch/cubic-flip-clock)。感谢原作者和贡献者提供翻页时钟的设计、代码与开放资源。本 fork 在原作基础上进行适配与扩展，保留原有署名和许可。

## 功能

- 七种配色，经典翻页 / 机械回弹；关闭秒显示后自动放大时分卡片。
- 城市和摄氏温度显示在左上角；中文底部显示农历，英语、德语、日语底部显示天气状况。
- 语言和天气地址自动跟随 Launcher，时间遵循系统时区。空地址中文默认上海，其他语言默认纽约。
- 独立通过固件天气服务查询城市编号及实时天气，每分钟刷新，不依赖 Weather 应用。
- 网页设置配色、动画和秒显示；设置保存在设备上，退出重开恢复。
- 完整字库保留在 SD 存储，运行时只读取当前文字及数字字形，组装小字体并释放旧缓存；非中文模式不加载农历数据。

## 操作

重力操作保持原作者逻辑：

| 操作 | 功能 |
| --- | --- |
| 左倾保持约 0.8 秒 | 下一种配色 |
| 右倾保持约 0.8 秒 | 显示 / 隐藏秒数 |
| 右倾后快速回正 | 切换翻页动画 |
| 前后倾 | 无功能 |
| Home | 退出应用 |

手柄沿用 Launcher 的 40 毫秒轮询和按键边沿响应：左右换色，上 / A / Menu 切换秒数，下切换动画，B / Select / Home 退出。

## 安装和使用

**[下载精简运行包（约 2.85 MB）](https://github.com/ClocTeck-Jie/cubic-flip-clock/releases/download/v1.2.1/flip-clock-1.2.1.zip)**

运行包只含应用运行文件、商店介绍和必要许可，不含开发工具、测试、记录、预览 GIF 或旧 RGB 图集。无需下载整个源码仓库。旧 RGB 图集仅在 `assets/legacy/` 保留用于资源构建，不在 `package/` 或运行 ZIP 中。

1. 下载上面的运行 ZIP，将解压后的文件和子目录上传至 `/sd/apps/flip-clock/`，保持目录结构。入口应为 `/sd/apps/flip-clock/main.lua`。
2. 在设备上重新扫描应用并启动翻页时钟。升级时保留设备已有的 `settings.json`，不要复制其他设备的运行缓存。
3. 在 Launcher 中设置语言、时区和天气地址，连接网络并完成校时。
4. 启动后从设备控制台进入应用网页调整外观；商店安装通常为 `http://设备IP/cubic-flip-clock/`，上述手动安装为 `http://设备IP/flip-clock/`。控制页不提供独立的语言、天气地址设置。

应用商店介绍见 [package/info.html](package/info.html)。安装时无需自行构建字体或运行开发工具。`/sd` 是固件提供的存储路径，不代表一定需要外置 SD 卡。

## 构建与验证

```sh
npm ci
npm test
npm run test:core
python tools/package_release.py
```

生成的 ZIP 在 `releases/`，不包含用户设置、天气缓存、临时字体和诊断记录。构建字体及其他资源见 [开发说明](docs/development.md)。

1.2.0 已完成中文/英语显示、独立天气、设置保存和退出重开的实机检查；重力映射、手柄按键、多语言和按需字体有本地回归测试。典型实测字体数据约 2.7 KB，大小随显示内容变化。Lua 接口未提供指定 PSRAM 的选项，实际内存区域由固件分配器决定。

短时检查不等同于长时间稳定性保证。完整范围和限制见 [验证记录](docs/validation.md)，不宣称本适配版本已获得原作者或社区审核认可。

## 七种皮肤与动效预览

以下 GIF 为七种皮肤的界面预览，按正常走时仅翻动秒卡片；这是 1.1.0 的历史外观示意，1.2.0 顶部改为城市与温度。棋盘格表示透明区域，不属于应用背景。GIF 由网页原型生成，不代表实机性能。

| 黑白 | 纯白 |
| --- | --- |
| ![黑白皮肤](docs/skins/dark.gif) | ![纯白皮肤](docs/skins/light.gif) |
| 琥珀 | 冰蓝 |
| ![琥珀皮肤](docs/skins/amber.gif) | ![冰蓝皮肤](docs/skins/ice.gif) |
| 紫晶 | 奶油 |
| ![紫晶皮肤](docs/skins/violet.gif) | ![奶油皮肤](docs/skins/cream.gif) |
| 血红 | |
| ![血红皮肤](docs/skins/blood.gif) | |

## 许可

代码采用 MIT 许可，保留 Cubic Flip Clock contributors 的版权声明。字体和其他第三方资源按各自许可分发，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 1.2.1 修复

修复商店按仓库名 `cubic-flip-clock` 安装后无法启动的问题：资源目录现在跟随当前应用路由，不再固定为 `flip-clock`。兼容原手动安装目录，并补充目录解析回归测试。
