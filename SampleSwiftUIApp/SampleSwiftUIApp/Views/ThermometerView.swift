import SwiftUI

/// The thermometer workflow: the object temperature as one large reading, and a Start/Stop button. The ambient
/// temperature is not displayed. It is driven by a ``SimpleSensorViewModel``.
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
