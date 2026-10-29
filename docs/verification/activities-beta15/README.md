# beta.15 (96)

锁屏使用 ActivityKit 默认系统背景（activityBackgroundTint(nil)），内容层不再画底色、外圆角和描边。系统负责随锁屏背景绘制材质及裁切；不在 Widget 内容上使用 glassEffect，避免重现透明框问题。内部目的地／教室色块保持连续圆角，App 内预览另用 ultraThinMaterial。标题与辅助文字采用自适应前景色。

工程结构检查通过。最终真机材质及圆角外观仍需观察；没有将构建成功作为视觉验收。
