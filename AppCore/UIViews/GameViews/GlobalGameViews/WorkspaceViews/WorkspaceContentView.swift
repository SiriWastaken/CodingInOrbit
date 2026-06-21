//
//  WorkspaceContentView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-20.
//

import SwiftUI

struct WorkspaceContentView: View {
    @Binding var codeLines: [CodeLine]
    @Binding var selectedIndex: Int?
    @FocusState var isWorkspaceFocused: Bool
    @State private var codeString: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                LineNumberView(count: codeLines.count)
                
                TextEditor(text: $codeString)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                    .focused($isWorkspaceFocused)
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
                    .onChange(of: codeString) { newValue in
                        codeLines = BlockParser.parseCode(newValue)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isWorkspaceFocused = true
                        }
                    }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.vertical, 4)
            
            BlockButtonsView { block in
                appendBlock(block)
            }
            .background(Color.gray.opacity(0.05))
            
            RunButtonView(codeLines: codeLines)
        }
        .background(Color.gray.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            codeString = codeLines.map { String(repeating: "    ", count: $0.depth) + $0.text }.joined(separator: "\n")
        }
        .onChange(of: codeLines) { newLines in
            codeString = newLines.map { String(repeating: "    ", count: $0.depth) + $0.text }.joined(separator: "\n")
        }
    }
    
    private func appendBlock(_ block: Block) {
        let newLine = CodeLine(depth: 0, text: block.command + "()")
        codeLines.append(newLine)
        codeString = codeLines.map { String(repeating: "    ", count: $0.depth) + $0.text }.joined(separator: "\n")
    }
}
