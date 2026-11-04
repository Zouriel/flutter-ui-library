import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/svg_path.dart';
import '../overlay/tooltip.dart';
import '../theme/theme.dart';

/// Which messenger a [UiMessengerButton] opens (the web `'whatsapp' | 'viber' | 'telegram'`).
enum UiMessengerApp { whatsapp, viber, telegram }

/// When a [UiMessengerButton] shows only its logo (the web `compact: boolean | 'auto'`).
enum UiMessengerCompact {
  /// Logo and label.
  off,

  /// Logo only.
  on,

  /// Logo only when the label would not fit in full in the width given (useful with
  /// `expand`, so a row of buttons turns icon-only on a narrow screen).
  auto,
}

/// A [UiMessengerButton]'s size (the web `size: 'sm' | 'md'`).
enum UiMessengerSize {
  /// A 32px box (icon-only: 32x32) inside an invisible hit area of at least 44x44.
  sm,

  /// 44px, the 0.57 look.
  md,
}

/// The messengers' brand colours and logos, the same in every theme and in both libraries. With the
/// sign-in buttons' brand files, the only literal colours outside the generated tokens
/// (`style_contract_test.dart` allows this file).
abstract final class UiMessengerBrand {
  /// WhatsApp green; the label ink is 7.46:1 on it.
  static const whatsappFill = Color(0xFF25D366);
  static const whatsappInk = Color(0xFF0A2E1A);

  /// Viber's Brand Center "Main Purple". Black ink (4.68:1): white would be only 4.48:1.
  static const viberFill = Color(0xFF7360F2);
  static const viberInk = Color(0xFF000000);

  /// Telegram: the official logo's own gradient, top to bottom. The ink is 6.53:1 on the top stop
  /// and 5.57:1 on the bottom one.
  static const telegramTop = Color(0xFF2AABEE);
  static const telegramBottom = Color(0xFF229ED9);
  static const telegramInk = Color(0xFF0B1F2E);

  /// The white the logos are drawn in (their official files' fill).
  static const logoWhite = Color(0xFFFFFFFF);

  /// The md button's height (the minimum touch target on the web).
  static const double height = 44;

  /// The sm button's painted height.
  static const double heightSm = 32;

  /// The smallest hit area of an sm button, invisible around its 32px box.
  static const double hitSm = 44;

  /// The painted height for [size].
  static double heightFor(UiMessengerSize size) => size == UiMessengerSize.sm ? heightSm : height;

  /// The box each logo is fitted into, aspect kept: 22 on md, 18 on sm; Telegram 28 / 23, since its
  /// plane fills only about half its disc (at the same size it looks small beside the other glyphs).
  static double logoSize(UiMessengerApp app, [UiMessengerSize size = UiMessengerSize.md]) => switch ((app == UiMessengerApp.telegram, size)) {
        (true, UiMessengerSize.md) => 28,
        (true, UiMessengerSize.sm) => 23,
        (false, UiMessengerSize.md) => 22,
        (false, UiMessengerSize.sm) => 18,
      };

  /// The fill for [app] on a box [height] tall around a logo box [logo] tall (default: the md
  /// button's). Telegram's two stops sit at the logo box's top and bottom edges (solid outside that
  /// band), so the disc and the button are the same blue at every height and the logo reads as the
  /// white plane on Telegram blue (the web `linear-gradient(top calc(50% - logo/2), bottom calc(50% +
  /// logo/2))`). WhatsApp's and Viber's two stops are the same colour.
  static Gradient fillGradient(UiMessengerApp app, {double height = UiMessengerBrand.height, double? logo}) {
    final f = fill(app);
    final top = f.first, bottom = f.last;
    logo ??= logoSize(app);
    final a = ((height - logo) / 2 / height).clamp(0.0, 1.0), b = ((height + logo) / 2 / height).clamp(0.0, 1.0);
    return LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom], stops: [a, b]);
  }

  /// The tick badge: an 18px circle centred 3px inside the top-end corner.
  static const double badgeSize = 18;
  static const double badgeOffset = -6;

  /// The sm tick badge: a 14px circle centred 2px inside the top-end corner.
  static const double badgeSizeSm = 14;
  static const double badgeOffsetSm = -5;

  /// The brand's name, the default label.
  static String name(UiMessengerApp app) => switch (app) {
        UiMessengerApp.whatsapp => 'WhatsApp',
        UiMessengerApp.viber => 'Viber',
        UiMessengerApp.telegram => 'Telegram',
      };

  /// The label ink for [app].
  static Color ink(UiMessengerApp app) => switch (app) {
        UiMessengerApp.whatsapp => whatsappInk,
        UiMessengerApp.viber => viberInk,
        UiMessengerApp.telegram => telegramInk,
      };

  /// The fill: one colour, or Telegram's two gradient stops (top, bottom).
  static List<Color> fill(UiMessengerApp app) => switch (app) {
        UiMessengerApp.whatsapp => const [whatsappFill],
        UiMessengerApp.viber => const [viberFill],
        UiMessengerApp.telegram => const [telegramTop, telegramBottom],
      };

  /// Each logo's SVG viewBox size.
  static Size viewBox(UiMessengerApp app) => switch (app) {
        UiMessengerApp.whatsapp => const Size(720, 720),
        UiMessengerApp.viber => const Size(132, 141),
        UiMessengerApp.telegram => const Size(1000, 1000),
      };
}

// LOGO PATHS BEGIN (written by a script from the official files; do not retype)
/// The official logos' path data, verbatim from the brands' own SVG downloads, as (evenOdd, d) per
/// path in drawing order. Shared with the Angular library (`messenger/src/logos.ts`).
const Map<UiMessengerApp, List<(bool, String)>> uiMessengerLogoPaths = {
  // WhatsApp Brand Resource Center, https://www.whatsappbrand.com/ -> "Logo pack" WhatsApp-Brand-Resource-Center.zip
  // > 01_Glyph/01_Digital RGB/03_SVG/Digital_Glyph_White_RGB_2026.svg (viewBox 0 0 720 720, fill #FFFFFF).
  UiMessengerApp.whatsapp: [
    (false, r'M360,0C161.18,0,0,161.18,0,360c0,65.41,17.45,126.75,47.94,179.61L0,720l187.02-44.21c51.34,28.18,110.28,44.21,172.98,44.21,198.82,0,360-161.18,360-360S558.82,0,360,0ZM360,655.52c-60.17,0-116.13-17.98-162.82-48.87l-110.49,28.14,30.99-105.61c-33.53-47.93-53.2-106.26-53.2-169.19,0-163.21,132.31-295.52,295.52-295.52s295.52,132.31,295.52,295.52-132.31,295.52-295.52,295.52Z'),
    (false, r'M444.35,407.52l87.1,41.06c4,1.88,6.56,5.94,6.2,10.34-.94,11.46-5.54,34.43-26.13,55.02-58.12,58.12-162.49-7.64-166.74-10.18-25.67-13.79-50.06-32.24-73.19-55.36s-41.58-47.52-55.37-73.19c-2.55-4.24-68.31-108.61-10.18-166.74,20.59-20.59,43.56-25.19,55.02-26.13,4.41-.36,8.46,2.2,10.34,6.2l41.07,87.1c1.94,4.12,1.09,9.02-2.13,12.24l-30.61,30.61c-6.62,6.62-8.56,16.93-4,25.11,11.17,20.03,26.19,39.32,43.59,57.07,17.75,17.4,37.04,32.43,57.07,43.59,8.18,4.56,18.48,2.62,25.11-4l30.61-30.61c3.22-3.22,8.12-4.08,12.24-2.13Z'),
  ],
  // Viber Brand Center, https://www.viber.com/en/brand-center/ -> https://www.viber.com/app/uploads/Rakuten-Viber-Logos-2026.zip
  // > Rakuten Viber Icon/SVG/Viber Icon White.svg (viewBox 0 0 132 141, fill #FFFFFF; the 4th path is evenodd).
  UiMessengerApp.viber: [
    (false, r'M42.5148 33.3465C43.2981 33.3692 43.6565 33.6716 43.876 33.9445C43.8778 33.947 43.8758 33.9502 43.8731 33.9494C43.8703 33.9483 43.8669 33.9516 43.8682 33.9543C46.6612 38.0426 48.9848 42.4407 50.8014 47.1371C52.251 50.366 51.6754 52.3782 50.7206 53.1485L47.7744 55.6194C47.1072 56.102 46.6008 56.7689 46.3247 57.5272C46.0485 58.2742 45.9906 59.0797 46.1747 59.8726L46.2088 60.0097C46.6346 61.6186 47.9234 63.6764 48.9359 65.1129C50.3628 67.1701 52.1709 69.3417 54.1731 71.4218C57.05 74.41 62.792 79.6972 69.0288 81.5591C69.8572 81.7429 70.7436 81.6617 71.5144 81.317C72.2737 80.9837 72.8962 80.4326 73.2874 79.7777L75.5657 76.6854L75.6456 76.56C76.0713 75.8591 76.7504 75.3422 77.5441 75.1238C78.3609 74.894 79.201 74.9733 79.9373 75.3523L80.2372 75.469C85.4384 77.009 90.3414 79.3066 94.7716 82.2602C95.3811 82.8004 95.6453 83.7546 95.5534 85.0986C95.4843 86.2248 95.1614 87.5934 94.6207 89.0758C93.4125 91.4658 91.7794 93.5811 89.697 95.4197C88.4584 96.6129 86.916 97.4204 85.3205 97.7924C85.163 97.829 85.0004 97.8448 84.8386 97.8449H84.564C78.6149 97.5116 72.8493 96.0633 67.395 93.5235L66.7037 93.2347C52.2971 87.0286 40.8817 75.7436 34.5642 61.4586L34.2302 60.8382C31.5375 55.8963 29.8456 50.5506 29.1897 44.9881C29.0978 44.1034 29.2238 43.184 29.5344 42.3568C29.868 41.495 30.3751 40.7595 31.0883 40.093C32.9869 38.2083 35.1054 36.5422 37.3147 35.1746L37.5328 35.0706C40.0759 33.657 41.5839 33.3582 42.4009 33.3582C42.4319 33.3581 42.4624 33.3456 42.4934 33.3456L42.5148 33.3465Z'),
    (false, r'M69.1271 43.2553C70.8203 43.4392 72.4828 43.863 74.0624 44.5165C76.2434 45.4187 78.2253 46.7419 79.8945 48.409C81.5637 50.0761 82.8886 52.0555 83.7919 54.2337C84.4461 55.8112 84.8706 57.4718 85.0547 59.1628C85.1705 60.2305 84.2871 61.1035 83.2116 61.1037H78.7193C77.6435 61.1037 76.7906 60.2239 76.5734 59.1715C76.4515 58.5804 76.2732 58 76.0409 57.4397C75.5591 56.2781 74.8523 55.2229 73.9622 54.3338C73.072 53.4448 72.0154 52.739 70.8524 52.2578C70.2912 52.0256 69.7094 51.8467 69.1174 51.7249C68.0639 51.5078 67.1837 50.657 67.1837 49.5827V45.096C67.1841 44.0219 68.0579 43.1395 69.1271 43.2553Z'),
    (false, r'M69.131 25.2493C73.1865 25.4691 77.1802 26.3744 80.9411 27.9303C85.3031 29.7347 89.2668 32.3801 92.6052 35.7143C95.9437 39.0486 98.5924 43.0073 100.399 47.3637C101.957 51.1199 102.863 55.1086 103.083 59.1589C103.142 60.2318 102.264 61.1035 101.188 61.1037H96.6945C95.6189 61.1035 94.7543 60.2315 94.6781 59.1599C94.4689 56.2103 93.7843 53.3084 92.6481 50.5687C91.2629 47.2291 89.2332 44.1943 86.6739 41.6382C84.1144 39.0819 81.0752 37.054 77.7311 35.6706C74.9879 34.5358 72.0823 33.853 69.129 33.6441C68.0564 33.5678 67.1841 32.7043 67.1837 31.6302V27.1426C67.1838 26.0681 68.0567 25.1911 69.131 25.2493Z'),
    (true, r'M65.0154 0C66.3158 0.0114935 68.7095 0.0694772 72.2077 0.161418C78.3526 0.333816 84.4176 0.977004 90.2403 2.1033C94.2446 2.87329 97.6965 3.75858 100.493 4.72392C103.542 5.78112 105.533 6.5274 106.419 6.95266L107.248 7.35524C108.893 8.13675 110.585 8.95273 112.104 9.89515C113.38 10.6874 114.071 11.1239 114.187 11.205C117.535 13.5265 120.355 16.3771 122.565 19.6755C123.877 21.6406 124.946 23.5716 125.821 25.5595C126.914 28.0305 127.651 29.8815 128.019 31.0653L128.306 31.9959C128.709 33.2715 129.055 34.3754 129.308 35.4557C130.355 39.9033 131.08 44.2363 131.482 48.3507C132.035 54.0971 132.15 60.476 131.805 67.3027C131.494 73.3822 130.872 79.3124 129.952 84.9207C129.641 86.8169 129.009 89.2194 128.088 92.0464C127.686 93.2876 127.191 94.5523 126.615 95.8164C125.441 98.3908 125.015 99.2188 124.866 99.4717C123.554 101.666 122.599 103.138 122.047 103.827C121.437 104.574 120.988 105.137 120.7 105.504C120.01 106.378 119.572 106.815 118.836 107.55L118.157 108.24C116.604 109.814 114.555 111.424 112.057 112.999C110.872 113.757 109.549 114.469 108.145 115.124C104.785 116.687 101.298 117.86 97.7772 118.63L96.6497 118.883C95.7752 119.078 95.0151 119.25 94.1981 119.377C91.1261 119.836 89.2276 120.101 88.5715 120.159C87.8582 120.216 87.1675 120.296 86.4772 120.365C85.5796 120.468 84.6812 120.561 83.7491 120.618C77.6735 121.009 72.6707 121.058 66.4915 120.886C66.1982 120.876 64.8597 120.987 64.1499 121.274C63.8943 121.377 63.6682 121.547 63.4216 121.671C63.2713 121.746 63.1366 121.829 62.9971 121.922C60.7599 123.425 42.1605 135.021 33.1573 140.606C31.4306 141.677 29.2043 140.438 29.2043 138.408V117.515C29.2156 117.044 28.8014 116.94 28.5023 116.859C28.2837 116.802 27.9268 116.71 27.6163 116.584C25.3613 115.642 23.6578 114.86 22.5301 114.263C20.6889 113.286 18.7895 112.056 16.8908 110.596C16.3387 110.171 15.7981 109.688 15.223 109.171L14.3594 108.412C14.1867 108.262 13.8759 107.964 13.4276 107.505C11.8166 105.85 10.3547 104.057 9.07742 102.16C8.12237 100.735 6.91445 98.839 5.99393 96.782C4.83168 94.1732 4.00308 92.2649 3.2551 89.702C2.27701 86.3692 1.51712 82.9672 1.06832 79.8642C0.492991 75.9568 0.159499 71.9916 0.0674314 68.0612C-0.0706565 62.016 -0.00162868 56.3726 0.320576 51.2698C0.550719 47.4888 0.930405 44.0064 1.45972 40.9264C1.943 38.0764 2.62174 35.1571 3.47319 32.2497C3.9795 30.4913 4.69297 28.5942 5.56747 26.6175C6.28091 25.0086 6.84486 23.8473 7.2246 23.1577C8.74349 20.4571 10.5048 17.9637 12.4725 15.7227C13.2319 14.8608 14.0953 14.0333 15.0273 13.2519C17.2021 11.4475 19.5839 9.87215 22.127 8.56199C27.0176 6.0451 32.1731 4.16028 37.4549 2.97652C40.0555 2.39039 43.1516 1.7355 46.3276 1.27579C52.1847 0.425356 58.0424 1.2161e-05 63.7614 0H65.0154ZM65.5334 8.84982C61.7475 8.76937 57.5584 8.91803 53.105 9.30879C46.1088 9.9294 39.7916 11.2748 33.7619 13.4123C31.541 14.2053 29.2964 15.2162 27.11 16.4229C25.2689 17.4342 23.6001 18.549 22.1387 19.7213C21.034 20.6062 19.9529 21.676 18.9403 22.8942C16.3281 26.0087 14.256 29.6403 12.7831 33.6742C10.9189 38.777 9.74465 44.5126 9.31888 50.7301C8.9967 55.4765 8.90544 60.6827 9.05502 66.1991C9.11256 68.463 9.28517 70.9913 9.56131 73.7264C9.96406 77.7258 10.758 81.7487 11.9087 85.6792C12.8868 89.058 14.1646 92.1151 15.8101 95.0113C18.3877 99.551 22.0241 103.401 26.0517 105.872C27.1768 106.553 28.0658 107.056 28.775 107.389C28.7916 107.397 28.8033 107.412 28.8071 107.43C28.8108 107.448 28.8235 107.463 28.8402 107.471C30.7422 108.361 32.7349 109.093 34.7735 109.654C35.2071 109.775 35.605 109.884 35.9672 109.981C37.1476 110.301 37.9756 111.373 37.9232 112.593C37.7159 117.407 37.1677 126.43 37.1677 126.537C37.1434 127 37.6574 127.295 38.0537 127.054C38.8622 126.558 56.2395 115.969 59.6001 113.107C61.0981 111.831 62.9542 111.895 63.1957 111.907C65.1519 111.941 65.4992 111.987 67.0757 112.021C68.2727 112.044 71.2648 112.032 75.9707 111.986C80.9303 111.929 85.396 111.596 89.6191 110.987C90.9997 110.78 92.0355 110.596 92.7143 110.412C93.8304 110.113 95.016 109.826 96.2817 109.527C96.7533 109.412 97.2026 109.286 97.6282 109.16C98.0192 109.045 98.3987 108.93 98.7897 108.838C99.342 108.711 99.9863 108.504 100.734 108.206C102.184 107.62 103.001 107.286 103.37 107.114C108.295 104.804 112.357 101.39 115.452 96.9541C115.832 96.4142 116.108 95.9659 116.327 95.5753C116.545 95.1616 116.764 94.7936 116.983 94.4259C117.409 93.7019 117.811 93.0117 118.18 92.1612C118.617 91.1388 118.916 90.438 119.066 90.0472C120.435 86.4155 121.39 82.6571 121.885 78.8646C122.656 73.0378 123.082 67.0957 123.151 61.2C123.243 52.6953 122.473 45.2476 120.781 38.4438C120.666 37.984 120.056 35.9725 119.573 34.3637C119.331 33.5593 118.951 32.5713 118.664 31.8588L118.502 31.4445C117.696 29.3528 116.591 27.2498 115.245 25.1696C114.06 23.3424 112.726 21.7448 111.287 20.4117C109.872 19.1015 108.249 17.9516 106.477 17.0092C104.67 16.0554 103.082 15.2851 101.748 14.7105C100.344 14.1129 98.675 13.5151 96.788 12.929C91.3104 11.2281 85.6022 10.0792 79.837 9.52758C75.1306 9.06788 71.3908 8.98772 65.7408 8.84982H65.5334Z'),
  ],
  // https://telegram.org/press#telegram-logos -> https://telegram.org/file/464001088/1/bI7AJLo7oX4.287931.zip/374fe3b0a59dc60005
  // > Logo.svg (viewBox 0 0 1000 1000): a r500 circle with the #2AABEE -> #229ED9 gradient (drawn by the painter), then this plane in #FFFFFF.
  UiMessengerApp.telegram: [
    (false, r'M226.328419,494.722069 C372.088573,431.216685 469.284839,389.350049 517.917216,369.122161 C656.772535,311.36743 685.625481,301.334815 704.431427,301.003532 C708.567621,300.93067 717.815839,301.955743 723.806446,306.816707 C728.864797,310.92121 730.256552,316.46581 730.922551,320.357329 C731.588551,324.248848 732.417879,333.113828 731.758626,340.040666 C724.234007,419.102486 691.675104,610.964674 675.110982,699.515267 C668.10208,736.984342 654.301336,749.547532 640.940618,750.777006 C611.904684,753.448938 589.856115,731.588035 561.733393,713.153237 C517.726886,684.306416 492.866009,666.349181 450.150074,638.200013 C400.78442,605.66878 432.786119,587.789048 460.919462,558.568563 C468.282091,550.921423 596.21508,434.556479 598.691227,424.000355 C599.00091,422.680135 599.288312,417.758981 596.36474,415.160431 C593.441168,412.561881 589.126229,413.450484 586.012448,414.157198 C581.598758,415.158943 511.297793,461.625274 375.109553,553.556189 C355.154858,567.258623 337.080515,573.934908 320.886524,573.585046 C303.033948,573.199351 268.692754,563.490928 243.163606,555.192408 C211.851067,545.013936 186.964484,539.632504 189.131547,522.346309 C190.260287,513.342589 202.659244,504.134509 226.328419,494.722069 Z'),
  ],
};
// LOGO PATHS END

final Map<UiMessengerApp, List<Path>> _logoPaths = {
  for (final e in uiMessengerLogoPaths.entries)
    e.key: [for (final (evenOdd, d) in e.value) uiParseSvgPath(d, fillType: evenOdd ? PathFillType.evenOdd : PathFillType.nonZero)],
};

/// A messenger's official logo in its official colours (never recoloured), fitted into a [size]
/// square with its aspect kept and centred. Decorative: excluded from semantics.
class UiMessengerLogo extends StatelessWidget {
  const UiMessengerLogo(this.app, {super.key, this.size});

  final UiMessengerApp app;

  /// The square; default [UiMessengerBrand.logoSize].
  final double? size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(dimension: size ?? UiMessengerBrand.logoSize(app), child: CustomPaint(painter: _LogoPainter(app))),
      );
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter(this.app);

  final UiMessengerApp app;

  @override
  void paint(Canvas canvas, Size size) {
    final box = UiMessengerBrand.viewBox(app);
    final scale = (size.width / box.width) < (size.height / box.height) ? size.width / box.width : size.height / box.height;
    canvas.save();
    canvas.translate((size.width - box.width * scale) / 2, (size.height - box.height * scale) / 2);
    canvas.scale(scale);
    if (app == UiMessengerApp.telegram) {
      // The circle with the logo's gradient: x 50%, y 0% -> 99.2583404% of the 1000 box.
      final shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment(0, 0.985166808),
        colors: [UiMessengerBrand.telegramTop, UiMessengerBrand.telegramBottom],
      ).createShader(const Rect.fromLTWH(0, 0, 1000, 1000));
      canvas.drawCircle(const Offset(500, 500), 500, Paint()..shader = shader..isAntiAlias = true);
    }
    final white = Paint()..color = UiMessengerBrand.logoWhite..isAntiAlias = true;
    for (final p in _logoPaths[app]!) {
      canvas.drawPath(p, white);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.app != app;
}

/// `ui-messenger-button`: opens a chat in WhatsApp, Viber or Telegram. The brand's fill, its
/// official logo and the label (default: the app's name) in the brand's dark ink, with the theme's
/// corners. Logo and label are centred together. [size] md is 44 high; sm is a 32px box (icon-only:
/// 32x32) inside an invisible hit area of at least 44x44 (48 on touch screens is not added: the 44
/// area is what lets a row of them sit 12 apart without overlapping). [compact] shows the logo only
/// (the full name stays the accessible name); auto does so exactly when the whole label would not fit
/// (it never ends in an ellipsis); [expand] fills the width (equal buttons in a row).
///
/// [ticked] adds a success tick badge at the top-end corner (e.g. "already opened"); the button stays
/// usable and its name gains ", [tickLabel]" (default [UiStrings.messengerOpened]); with [tickLabel]
/// set, a tooltip shows it (hover, keyboard focus, long press on touch). A long press never presses
/// the button. Hover lays a 10% white veil over the fill, press 18% (a white veil only raises the dark
/// ink's contrast). [onPressed] null disables it. [UiMessengerCompact.auto] measures the space it is
/// given, so it can't sit inside intrinsic sizing (IntrinsicWidth); [UiMessengerCompact.on] and off
/// can (e.g. in a [UiTable] cell). Nothing hides an app by platform. Twin of Angular's
/// `ui-messenger-button`.
class UiMessengerButton extends StatelessWidget {
  const UiMessengerButton({
    super.key,
    required this.app,
    required this.onPressed,
    this.label,
    this.size = UiMessengerSize.md,
    this.compact = UiMessengerCompact.off,
    this.expand = false,
    this.ticked = false,
    this.tickLabel,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  final UiMessengerApp app;
  final VoidCallback? onPressed;

  /// The visible words; defaults to the app's name.
  final String? label;

  /// md (44) or sm (a 32px box with a 44px hit area).
  final UiMessengerSize size;
  final UiMessengerCompact compact;

  /// Fill the available width.
  final bool expand;

  /// Show the tick badge.
  final bool ticked;

  /// What the tick means ("Opened 14:05"): read after the name and shown as a tooltip.
  final String? tickLabel;

  /// The accessible name (the web `ariaLabel`); defaults to [label], then the app's name.
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  bool get _sm => size == UiMessengerSize.sm;

  /// The label's style in [context]: md 15/600/20, sm 13/600/18.
  TextStyle labelStyle(BuildContext context) {
    final t = context.ui;
    final fs = _sm ? t.fontSizeSm : t.fontSizeMd;
    return context.uiText.body.copyWith(
      fontSize: fs,
      fontWeight: FontWeight.w600,
      height: (_sm ? 18 : 20) / fs,
      leadingDistribution: TextLeadingDistribution.even,
      color: UiMessengerBrand.ink(app),
      decoration: TextDecoration.none,
    );
  }

  double _pad(UiTokens t) => _sm ? 10 : t.space3;
  double _gap(UiTokens t) => _sm ? 6 : t.space2;

  /// The width the button needs to show its logo and its whole label on one line: padding, logo,
  /// gap, the label's natural width (at the current text scale), padding.
  /// [UiMessengerCompact.auto] shows the label only when it has at least this much.
  double labelledWidth(BuildContext context) {
    final t = context.ui;
    final words = (label ?? '').isNotEmpty ? label! : UiMessengerBrand.name(app);
    final p = TextPainter(
      text: TextSpan(text: words, style: labelStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final w = p.width;
    p.dispose();
    return _pad(t) + UiMessengerBrand.logoSize(app, size) + _gap(t) + w + _pad(t);
  }

  /// The accessible name the button gets in [context].
  String accessibleName(BuildContext context) {
    String? nonEmpty(String? v) => (v ?? '').isEmpty ? null : v;
    final base = nonEmpty(semanticLabel) ?? nonEmpty(label) ?? UiMessengerBrand.name(app);
    return ticked ? '$base, ${nonEmpty(tickLabel) ?? context.uiStrings.messengerOpened}' : base;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final fill = UiMessengerBrand.fill(app);
    final radius = BorderRadius.circular(theme.radius());
    final words = (label ?? '').isNotEmpty ? label! : UiMessengerBrand.name(app);
    final style = labelStyle(context);
    final h = UiMessengerBrand.heightFor(size);
    final logo = UiMessengerBrand.logoSize(app, size);

    Widget buildFor(bool iconOnly) {
      return UiInteractive(
        onTap: onPressed,
        enabled: onPressed != null,
        focusNode: focusNode,
        autofocus: autofocus,
        semanticLabel: accessibleName(context),
        excludeChildSemantics: true,
        // sm makes its own 44 hit area below; md keeps the usual 48 on touch screens.
        padTouchTarget: !_sm,
        builder: (context, s) {
          final veil = s.pressed ? 0.18 : s.hovered ? 0.10 : 0.0;
          final content = Row(
            key: const ValueKey('ui-messenger-content'),
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              UiMessengerLogo(app, size: logo),
              if (!iconOnly) ...[
                SizedBox(width: _gap(t)),
                Flexible(child: Text(words, style: style, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false)),
              ],
            ],
          );
          Widget face = Container(
            key: const ValueKey('ui-messenger-box'),
            height: h,
            width: iconOnly && !expand ? h : null,
            padding: iconOnly && !expand ? null : EdgeInsets.symmetric(horizontal: _pad(t)),
            // Only a box wider than its content centres it (an Align would make a hugging button fill).
            alignment: expand || iconOnly ? Alignment.center : null,
            decoration: BoxDecoration(
              color: fill.length == 1 ? fill.first : null,
              gradient: fill.length > 1 ? UiMessengerBrand.fillGradient(app, height: h, logo: logo) : null,
              borderRadius: radius,
              boxShadow: s.focused ? t.focusRing : null,
            ),
            foregroundDecoration: veil > 0 ? BoxDecoration(color: UiMessengerBrand.logoWhite.withValues(alpha: veil), borderRadius: radius) : null,
            child: content,
          );
          if (expand) face = SizedBox(width: double.infinity, child: face);
          if (ticked) {
            final off = _sm ? UiMessengerBrand.badgeOffsetSm : UiMessengerBrand.badgeOffset;
            face = Stack(clipBehavior: Clip.none, children: [
              face,
              PositionedDirectional(top: off, end: off, child: UiMessengerTick(size: size)),
            ]);
          }
          face = Opacity(opacity: s.disabled ? 0.5 : 1, child: face);
          // The invisible hit area: at least 44x44, the painted box centred in it.
          if (_sm) face = UiTouchTarget(key: const ValueKey('ui-messenger-hit'), minSize: const Size.square(UiMessengerBrand.hitSm), child: face);
          return face;
        },
      );
    }

    // Only auto needs its width, and a LayoutBuilder can't report intrinsic sizes, so the other modes
    // build directly and work inside IntrinsicWidth (a table's natural-width columns). Auto never
    // ellipsizes: the whole label, or the logo alone.
    Widget button = compact == UiMessengerCompact.auto
        ? LayoutBuilder(builder: (context, box) => buildFor(box.maxWidth < labelledWidth(context)))
        : buildFor(compact == UiMessengerCompact.on);
    final tip = tickLabel;
    if (ticked && tip != null && tip.isNotEmpty) {
      // The tooltip's own long press shows it and wins over the tap.
      button = UiTooltip(message: tip, child: button);
    } else {
      // A long press is never a press: it wins the gesture over the tap and does nothing.
      button = GestureDetector(excludeFromSemantics: true, onLongPress: () {}, child: button);
    }
    return button;
  }
}

/// The tick badge on a ticked [UiMessengerButton]: a success circle (18px on md, 14 on sm) with a
/// 2px ring around it in the surface colour and a tick (12 / 10). Decorative: no semantics, no hits.
class UiMessengerTick extends StatelessWidget {
  const UiMessengerTick({super.key, this.size = UiMessengerSize.md});

  final UiMessengerSize size;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final sm = size == UiMessengerSize.sm;
    final d = sm ? UiMessengerBrand.badgeSizeSm : UiMessengerBrand.badgeSize;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('ui-messenger-tick'),
          width: d,
          height: d,
          alignment: Alignment.center,
          // The ring sits outside the disc (the web `box-shadow: 0 0 0 2px surface`).
          decoration: BoxDecoration(color: t.success, shape: BoxShape.circle, boxShadow: [BoxShadow(color: t.surface, spreadRadius: 2)]),
          child: UiIcon(HugeIcons.strokeRoundedTick02, size: sm ? 10 : 12, strokeWidth: 2.5, color: t.successContrast),
        ),
      ),
    );
  }
}
