public enum ColorOption: String, CaseIterable, Equatable {
    case auto
    case always
    case never

    public static let `default` = ColorOption.auto
}
