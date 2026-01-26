
import SwiftUI

struct EmojiPickerView: View {
    let onSelected: (String) -> Void
    
    let emojis = [
        "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇",
        "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚",
        "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🤩",
        "🥳", "😏", "😒", "😞", "😔", "😟", "😕", "🙁", "☹️", "😣",
        "😖", "😫", "😩", "🥺", "😢", "😭", "😤", "😠", "😡", "🤬",
        "🤯", "😳", "🥵", "🥶", "😱", "😨", "😰", "😥", "😓", "🤗",
        "🤔", "🤭", "🤫", "🤥", "😶", "😐", "😑", "😬", "🙄", "😯",
        "😦", "😧", "😮", "😲", "🥱", "😴", "🤤", "😪", "😵", "🤐",
        "🥴", "🤢", "🤮", "🤧", "🤨", "🧐", "🧤", "🧣", "🐨", "🦁"
    ]
    
    let columns = [
        GridItem(.adaptive(minimum: 45))
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 6)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            Text("Wähle ein Emoji")
                .font(.headline)
                .padding(.bottom, 20)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button(action: {
                            onSelected(emoji)
                        }) {
                            Text(emoji)
                                .font(.system(size: 35))
                                .frame(width: 50, height: 50)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
