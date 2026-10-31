/// Discrete events from the Nuimo that can trigger an action. Raw values are the event names in `config.toml`.
enum Gesture: String, CaseIterable, Sendable {
    case press
    case longPress = "long_press"
    case doublePress = "double_press"
    case swipeLeft = "swipe_left"
    case swipeRight = "swipe_right"
    case swipeUp = "swipe_up"
    case swipeDown = "swipe_down"
    case touchLeft = "touch_left"
    case touchRight = "touch_right"
    case touchTop = "touch_top"
    case touchBottom = "touch_bottom"
    case longTouchLeft = "longtouch_left"
    case longTouchRight = "longtouch_right"
    case longTouchTop = "longtouch_top"
    case longTouchBottom = "longtouch_bottom"
    case flyLeft = "fly_left"
    case flyRight = "fly_right"

    /// Image shown on the LED matrix after the gesture's action ran.
    var feedbackImage: MatrixImage {
        switch self {
        case .press: .smiley
        case .longPress: .circle
        case .doublePress: .twoDots
        case .swipeLeft, .flyLeft: .arrowLeft
        case .swipeRight, .flyRight: .arrowRight
        case .swipeUp: .arrowUp
        case .swipeDown: .arrowDown
        case .touchLeft, .longTouchLeft: .dotLeft
        case .touchRight, .longTouchRight: .dotRight
        case .touchTop, .longTouchTop: .dotTop
        case .touchBottom, .longTouchBottom: .dotBottom
        }
    }
}
