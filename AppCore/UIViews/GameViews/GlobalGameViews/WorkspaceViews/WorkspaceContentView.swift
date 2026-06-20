//
//  WorkspaceContentView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-20.
//

import SwiftUI

struct CodeLine: Identifiable {
    let id = UUID()
    let depth: Int
    let text: String
}

struct WorkspaceContentView: View {
    @Binding var codeLines: [CodeLine]
    @Binding var selectedIndex: Int?
    @FocusState var isWorkspaceFocused: Bool
    @State private var codeString: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextEditor(text: $codeString)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
                .focused($isWorkspaceFocused)
                .frame(minHeight: 200)
                .scrollContentBackground(.hidden)            .font(.system(.body, design: .monospaced))
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.vertical, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(blocksArray) { block in
                        Button {
                            appendBlock(block)
                        } label: {
                            Label(block.title, systemImage: block.icon)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.3))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .scrollDisabled(true)
            }
            .background(Color.gray.opacity(0.05))
            
            HStack {
                Spacer()
                Button("▶ Run") {
                    print("Executing code:")
                    codeLines.forEach { print(String(repeating: "  ", count: $0.depth) + $0.text) }
                }
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.3))
                .cornerRadius(8)
                .padding(8)
            }
        }
        .background(Color.gray.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            
        )
        .onChange(of: codeLines) { newLines in
        codeString = newLines.map { String(repeating: "    ", count: $0.depth) + $0.text }.joined(separator: "\n")}
    }
       
    
    
    
    private func appendBlock(_ block: Block) {
        let newLine = CodeLine(depth: 0, text: block.command + "()")
        codeLines.append(newLine)
                codeString = codeLines.map { String(repeating: "    ", count: $0.depth) + $0.text }.joined(separator: "\n")
    }
}

func parseCode(_ text: String) -> [CodeLine] {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    var result: [CodeLine] = []
    
    for line in lines {
        let lineString = String(line)
        let leadingSpaces = lineString.prefix(while: { $0 == " " || $0 == "\t" }).count
        let depth = leadingSpaces / 4
        let trimmed = lineString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            result.append(CodeLine(depth: depth, text: trimmed))
        }
    }
    return result
}
