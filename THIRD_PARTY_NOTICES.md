# 第三方资源来源

## 中文字体：SIL Open Font License 1.1

设备字体由 Noto Sans SC Medium（SIL Open Font License 1.1）构建，保留源字体的字符轮廓。完整许可见 licenses/OFL-NotoSansCJK.txt。三份 .bin 是存储在 SD 卡的字形库，glyph*.idx 是按 Unicode 编号寻址的索引。运行时只读取当前文本所需的字形记录，组装小型 LVGL 字体并释放被替换的字体，不把整库载入内存。原始 1.1.0 的 CubicClockCJK.ttf 子集保留在 assets 目录作为上游资源记录，不是本次设备字库的构建输入。

## 农历数据：MIT

package/lunar_data.lua 由 lunar-javascript 1.7.7 生成，作者 6tail，Copyright (c) 2018 6tail，许可全文见 licenses/lunar-javascript-MIT.txt。原项目：https://github.com/6tail/lunar-javascript 。设备只使用日期月表，不包含库中命理、黄历等其他功能。

香港天文台的年度公农历表仅下载到 _temp 用作独立测试，不打入应用。官方参考入口：https://www.hko.gov.hk/tc/gts/time/conversion.htm 。

## 数字图片

assets/legacy/ 下的旧 RGB 图集及 package/skins/ 下的压缩数字图片由本项目使用 Windows 本机 Arial Bold 绘制，不包含或分发 Arial TTF/OTF 文件。黑白普通帧保留已验收外观；重新构建需要合法可用的本机字体。Arial 字体本身不适用本项目 MIT 许可。

## API 参考

接口参考 Clocteck holocubic-apps 仓库。项目并非官方产品；第三方商标归各自权利人所有。
