// PBI-036: "Share to LifeOS" on iPhone.
//
// The plugin copies what was shared into the App Group container and opens
// LifeOS; the Dart side (mapSharedMedia → ShareInListener) takes it from
// there, exactly as on Android. LifeOS has its own confirm step (capture) and
// its own sheet (new task), so the extension shows no compose UI of its own.
//
// "No such module 'receive_sharing_intent'": add the plugin's Swift package
// library to this target, and move "Embed Foundation Extensions" above
// "Thin Binary" in Runner's Build Phases (plugin README, iOS steps 5 and 7).
import receive_sharing_intent

class ShareViewController: RSIShareViewController {

    // Straight to the app: no Cancel/Send sheet in front of LifeOS's own.
    override func shouldAutoRedirect() -> Bool {
        return true
    }
}
