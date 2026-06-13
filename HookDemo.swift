
import FoundationModels
import SwiftUI

struct HookDemoView: View {
    @State private var manager = SessionManager()
    @State private var scrollPosition: ScrollPosition = .init()
    @State private var entry: String = ""
    @State private var entryHeight: CGFloat = 24
    @State private var error: Error?

    var body: some View {
        let transcript = manager.session?.transcript ?? Transcript()

        ScrollViewReader { proxy in
            List {
                VStack(alignment: .leading, spacing: 8) {
                    Text("FoundationModel + Hook")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("For Human in loop, logging, and etc.")
                        .font(.caption)
                }
                .foregroundStyle(.white)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)


                if transcript.isEmpty {
                    Text("Enter something to start")
                }
                ForEach(transcript, id: \.id) { transcript in
                    self.transcriptView(transcript)
                        .id(transcript.id)
                }

                if manager.session?.isResponding == true {
                    ProgressView()
                        .padding(.all, 16)
                }

                if let error {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                }
            }
            .font(.headline)
            .scrollTargetLayout()
            .frame(maxWidth: .infinity)
            .scrollPosition($scrollPosition, anchor: .bottom)
            .defaultScrollAnchor(.bottom, for: .alignment)
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .onChange(
                of: transcript,
                initial: true,
                {
                    if let last = transcript.last {
                        proxy.scrollTo(last.id)
                    }
                }
            )
        }
        .frame(minWidth: 480, minHeight: 400)
        .padding(.bottom, entryHeight)
        .overlay(
            alignment: .bottom,
            content: {

                HStack(spacing: 12) {
                    TextEditor(text: $entry)
                        .onSubmit({
                            self.sendPrompt()
                        })
                        .textEditorStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(.background.opacity(0.8))
                        .padding(.all, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.gray, style: .init(lineWidth: 1))
                                .fill(.white)
                        )
                        .frame(maxHeight: 120)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(
                        action: {
                            self.sendPrompt()
                        },
                        label: {
                            Image(systemName: "paperplane.fill")
                        }
                    )
                    .buttonStyle(.glass)
                    .foregroundStyle(.blue)
                    .disabled(self.manager.session?.isResponding ?? false)

                }

                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(.yellow.opacity(0.2))
                .background(.white)
                .onGeometryChange(
                    for: CGFloat.self,
                    of: {
                        $0.size.height
                    },
                    action: { old, new in
                        self.entryHeight = new
                    }
                )
            }
        )
        .sheet(
            isPresented: $manager.showPermissionRequest,
            content: {
                VStack {
                    if let toolName = manager.requestingPermissionForTool {
                        Text("Requesting permission to use \(toolName)")
                    }

                    HStack {
                        Button(
                            action: {
                                manager.receivedPermission(.denied)
                            },
                            label: {
                                Text("Deny")
                            }
                        )

                        Button(
                            action: {
                                manager.receivedPermission(.allowed)
                            },
                            label: {
                                Text("Allow")
                            }
                        )

                    }
                }
                .padding(.all, 24)
                .interactiveDismissDisabled()
            }
        )
    }

    private func sendPrompt() {
        self.error = nil
        let entry = self.entry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }

        self.entry = ""
        Task {
            do {
                try await self.manager.respond(to: entry)
            } catch (let error) {
                self.error = error
            }
        }

    }

    @ContentBuilder
    private func transcriptView(_ entry: Transcript.Entry) -> some View {
        Group {
            switch entry {
            case .instructions(let instructions):
                Text("**Instructions**: \(instructions.description)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)

            case .prompt(let prompt):
                VStack(alignment: .leading, spacing: 8) {
                    Text("**User prompt**")
                    ForEach(prompt.segments) { segment in
                        self.segmentView(segment)
                    }
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.all, 16)
                .background(RoundedRectangle(cornerRadius: 24).fill(.yellow))
                .padding(.leading, 64)

            case .toolCalls(let toolCalls):
                Text("**Tool call**: \(toolCalls.description)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)

            case .toolOutput(let toolOutput):
                VStack(alignment: .leading, spacing: 8) {
                    Text("**Tool Output**")
                    ForEach(toolOutput.segments) { segment in
                        self.segmentView(segment)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)

            case .response(let response):
                VStack(alignment: .leading, spacing: 8) {
                    Text("**Assistant Response**")
                    ForEach(response.segments) { segment in
                        self.segmentView(segment)
                    }
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.all, 16)
                .background(RoundedRectangle(cornerRadius: 24).fill(.green))
                .padding(.trailing, 64)

            case .reasoning(let reasoning):
                Text("**Reasoning**: \(reasoning.description)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)

            default:
                Text("Unknown transcript entry")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)

            }
        }
        .listRowInsets(.all, 0)
        .padding(.vertical, 16)
        .listRowSeparator(.hidden)
    }

    @ContentBuilder
    private func segmentView(_ segment: Transcript.Segment) -> some View {
        switch segment {
        case .text(let textSegment):
            Text(textSegment.content)

        case .structure(let structuredSegment):
            Text(structuredSegment.content.jsonString)

        case .attachment(let attachmentSegment):
            switch attachmentSegment.content {
            case .image(let image):
                VStack(spacing: 4) {
                    Image(attachement: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)
                    Text(
                        "size: \(image.cgImage.width) * \(image.cgImage.height)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            default:
                Text("Unknown attachment")
            }
        case .custom(let customSegment):
            Text("Custom Segment: \(customSegment.description)")
        default:
            Text("Unknown Segment")

        }
    }
}

enum PermissionRequestState: String, Identifiable, Hashable {
    case initiated
    case denied
    case allowed
    var id: String { self.rawValue }
}

enum PermissionError: Error, LocalizedError {
    case denied

    var errorDescription: String? {
        switch self {
        case .denied:
            return "Tool use Permission denied"
        }
    }
}

@Observable
class SessionManager {
    var session: LanguageModelSession?
    private(set) var requestingPermissionForTool: String?
    var showPermissionRequest: Bool = false
    private var permissionRequest: PermissionRequestState? {
        didSet {
            if self.permissionRequest == .initiated {
                self.showPermissionRequest = true
            }
        }
    }
    private var requestForPermissionTask: Task<Void, Error>?

    init() {
        self.session = LanguageModelSession(
            profile: HookProfile(requestForPermission: {
                try await self.requestForPermission(toolCall: $0)
            })
        )
        self.session?.transcriptErrorHandlingPolicy = .preserveTranscript
    }

    func receivedPermission(_ permission: PermissionRequestState) {
        self.showPermissionRequest = false
        self.permissionRequest = permission
        self.requestForPermissionTask?.cancel()
    }

    private func requestForPermission(toolCall: Transcript.ToolCall)
        async throws
    {
        self.requestingPermissionForTool = toolCall.toolName
        self.permissionRequest = .initiated
        self.requestForPermissionTask = Task {
            while self.permissionRequest == .initiated
                || self.requestForPermissionTask?.isCancelled == false
            {
                try await Task.sleep(for: .milliseconds(200))
            }
        }
        try? await self.requestForPermissionTask?.value

        let requestState = self.permissionRequest
        self.permissionRequest = nil
        if requestState == .denied {
            throw PermissionError.denied
        }
    }

    func respond(to prompt: String) async throws {
        guard let session else {
            return
        }
        if session.isResponding {
            return
        }
        let _ =
            try await session.respond(to: prompt)
    }

}


struct HookProfile: LanguageModelSession.DynamicProfile {
    var requestForPermission: (Transcript.ToolCall) async throws -> Void

    var body: some LanguageModelSession.DynamicProfile {
        Profile {
            GreetingTool()
            ScheduleTool()
        }
        // Runs before the framework invokes the tool and allows for checking
        // whether the app is in a state to run the tool.
        .onToolCall { toolCall in
            try await requestForPermission(toolCall)
        }
        .onToolOutput { toolCall, output in
            // Runs when a tool call produces output.
        }
        .onActivate {
            // Runs when the profile becomes active and
            // allows for set up work.
        }
        .onDeactivate {
            // Runs when the profile becomes inactive and
            // allows for teardown work.
        }
        .onPrompt {
            // Runs after the user prompt appends to the transcript,
            // but before the model request starts.
        }
        .onResponse {
            // Runs after the model produces a response.
        }

    }
}

private struct GreetingTool: Tool {
    let name = "Greet Tool"
    let description = "greet"

    @Generable
    struct Arguments {
        @Guide(description: "The person to greet.")
        var name: String
    }

    // respond with image
    func call(arguments: Arguments) async throws -> String {
        return "\(arguments.name) greeted!"
    }
}

private struct ScheduleTool: Tool {
    let name = "Schedule Tool"
    let description = "create a schedule"

    @Generable
    struct Arguments {
        @Guide(description: "The name of the schedule event.")
        var name: String
        @Guide(description: "The date of the schedule event in ISO Format")
        var date: String
    }

    // respond with image
    func call(arguments: Arguments) async throws -> String {
        return "\(arguments.name) scheduled for \(arguments.date)!"
    }
}
