pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Polkit

Item {
    id: root

    // Agent status
    readonly property bool isRegistered: agent.isRegistered
    readonly property bool isActive: agent.isActive
    readonly property var flow: agent.flow

    // Active flow properties (safe fallbacks when flow is null)
    readonly property string message: flow ? (flow.message || "") : ""
    readonly property string actionId: flow ? (flow.actionId || "") : ""
    readonly property string iconName: flow ? (flow.iconName || "") : ""
    readonly property string inputPrompt: flow ? (flow.inputPrompt || "") : ""
    readonly property bool responseVisible: flow ? flow.responseVisible : false
    readonly property bool isResponseRequired: flow ? flow.isResponseRequired : false
    readonly property string supplementaryMessage: flow ? (flow.supplementaryMessage || "") : ""
    readonly property bool supplementaryIsError: flow ? flow.supplementaryIsError : false
    readonly property var identities: flow ? (flow.identities || []) : []
    readonly property var selectedIdentity: flow ? flow.selectedIdentity : null

    // Submission state
    property bool isSubmitting: false

    // Signals for shell and widgets
    signal authRequested()
    signal authCompleted(bool success)
    signal authFailed(string message)

    PolkitAgent {
        id: agent

        onFlowChanged: {
            root.isSubmitting = false;
            if (flow) {
                root.authRequested();
            } else {
                root.authCompleted(false);
            }
        }
    }

    Connections {
        target: agent.flow
        ignoreUnknownSignals: true

        function onAuthenticationSucceeded() {
            root.isSubmitting = false;
            root.authCompleted(true);
        }

        function onAuthenticationFailed() {
            root.isSubmitting = false;
            var err = (agent.flow && agent.flow.supplementaryMessage !== "") 
                ? agent.flow.supplementaryMessage 
                : "Authentication failed. Please try again.";
            root.authFailed(err);
        }

        function onAuthenticationRequestCancelled() {
            root.isSubmitting = false;
            root.authCompleted(false);
        }

        function onSupplementaryMessageChanged() {
            if (agent.flow && agent.flow.supplementaryIsError) {
                root.isSubmitting = false;
            }
        }
    }

    // Submit authentication response (password, pin, etc.)
    function submit(response) {
        if (!agent.flow) return;
        root.isSubmitting = true;
        agent.flow.submit(response);
    }

    // Cancel authentication request
    function cancel() {
        root.isSubmitting = false;
        if (agent.flow) {
            agent.flow.cancelAuthenticationRequest();
        }
    }

    // Select identity if multiple are available
    function selectIdentity(identity) {
        if (agent.flow && identity) {
            agent.flow.selectedIdentity = identity;
        }
    }
}
