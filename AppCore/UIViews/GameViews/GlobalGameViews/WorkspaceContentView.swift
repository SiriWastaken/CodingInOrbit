//
//  SwiftUIView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-20.
//

var WorkspaceContent: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Type a command...", text: $typedCommand)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
                .onSubmit {
                    if let matchingBlock = blocksArray.first(where: { $0.title.lowercased() == typedCommand.lowercased() }) {
                        workspace.append(matchingBlock)
                        typedCommand = ""
                    } else {
                        typedCommand = ""
                    }
                }
                .focused($isWorkspaceFocused)
            
            ForEach(workspace.indices, id: \.self) { index in
                HStack(spacing: 0) {
                    Text("\(index + 1).")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(width: 30, alignment: .trailing)
                    
                    Text(workspace[index].title)
                        .font(.body)
                        .padding(.vertical, 4)
                }
                .padding(.horizontal, 8)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(4)
                .background(selectedIndex == index ? Color.blue : Color.blue.opacity(0.2))
                .onTapGesture{
                    workspace.remove(at: index)
                }
            }
        }
        .padding(.vertical, 4)
    }
    .scrollDismissesKeyboard(.interactively)
    .frame(width: 300)
    .background(Color.gray.opacity(0.1))
    .overlay(
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
    )
}

#Preview {
    WorkspaceContent()
}
