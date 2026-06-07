/// Spec sheet passed to [GaugeWidget] — holds both OBD value range and display settings.
/// To add a new gauge, create a [GaugeConfig] and pass it to [GaugeWidget].
///
/// [GaugeWidget] に渡す仕様書。OBDの値範囲と表示設定をまとめて持つ。
/// 新しいゲージを追加する場合は [GaugeConfig] を作成して [GaugeWidget] に渡す。
class GaugeConfig {
  // --- OBD value range / OBD値の範囲 ---

  /// Display name shown above the value (e.g. 'ENGINE RPM').
  /// 値の上に表示するラベル（例: 'ENGINE RPM'）
  final String label;

  /// Unit shown next to the value (e.g. 'rpm', '°C').
  /// 値の横に表示する単位（例: 'rpm', '°C'）
  final String unit;

  /// Minimum and maximum OBD value for this gauge.
  /// このゲージのOBD値の最小・最大
  final double minValue;
  final double maxValue;

  // --- Display settings / 表示設定 ---

  /// Gauge diameter in pixels / ゲージの直径（px）
  final double size;

  /// Font size for the value display / 値表示のフォントサイズ
  final double valueFontSize;

  /// Number of decimal places / 小数点以下の桁数
  final int decimals;

  const GaugeConfig({
    required this.label,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    this.size = 180,
    this.valueFontSize = 36,
    this.decimals = 0,
  });
}
