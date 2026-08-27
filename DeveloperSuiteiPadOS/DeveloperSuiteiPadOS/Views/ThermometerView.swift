import SwiftUI

/// Matches Android's `ThermometerView` composable (`MainActivity.kt`)
/// exactly: title bar, single large Object Temp reading (no Ambient Temp —
/// Android doesn't show it either), status strip, Start/Stop action button.
struct ThermometerView: View {
    @ObservedObject var viewModel: SimpleSensorViewModel

    var body: some View {
        WorkflowScaffold(
            title: "Thermometer",
            statusMessage: viewModel.statusMessage
        ) {
            ReadingBorder(text: viewModel.lastReading?.tempObject ?? "—")
        } actionButton: {
            WorkflowActionButton(
                title: viewModel.buttonTitle,
                state: viewModel.actionState,
                action: viewModel.onActionButtonTapped
            )
        }
    }
}
