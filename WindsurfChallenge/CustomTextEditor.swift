import SwiftUI

struct CustomTextEditor: View {
    @Binding var text: String
    var onSubmit: (() -> Void)?
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextEditor(text: $text)
            .focused($isFocused)
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    guard isFocused else { return event }
                    
                    if event.keyCode == 36 { // Return/Enter key
                        if let onSubmit = onSubmit, !event.modifierFlags.contains(.shift) {
                            onSubmit()
                            return nil
                        }
                    }
                    return event
                }
            }
    }
}
