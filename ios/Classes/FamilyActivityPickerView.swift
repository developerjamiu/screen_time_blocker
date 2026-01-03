import SwiftUI
import FamilyControls

@available(iOS 16.0, *)
struct FamilyActivityPickerView: View {
    @Binding var selection: FamilyActivitySelection
    var onDismiss: () -> Void
    
    @State private var isPresented = true
    
    var body: some View {
        Color.clear
            .familyActivityPicker(isPresented: $isPresented, selection: $selection)
            .onChange(of: isPresented) { isShowing in
                if !isShowing { onDismiss() }
            }
    }
}
