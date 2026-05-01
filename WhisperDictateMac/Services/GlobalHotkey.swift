import Carbon
import Foundation

final class GlobalHotkey {
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?

    func register(action: @escaping () -> Void) {
        unregister()
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                var hotkeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )

                if hotkeyID.id == 1 {
                    let manager = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
                    manager.action?()
                }

                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )

        var hotkeyID = EventHotKeyID(signature: OSType(0x57444D43), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(controlKey | shiftKey),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
    }

    func unregister() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit {
        unregister()
    }
}

