import SwiftUI

struct AnnouncementDetailView: View {
    let announcement: Announcement

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "megaphone.fill")
                                .font(.omyu(size: 40))
                                .foregroundStyle(.teal)

                            Spacer()
                        }

                        Text(LocalizedStringKey(announcement.titleKey))
                            .font(.omyuTitle2)
                            .foregroundStyle(.white)

                        Text(announcement.formattedDate)
                            .font(.omyuSubheadline)
                            .foregroundStyle(.gray)
                    }
                    .padding(.top, 20)

                    Divider()
                        .background(Color.gray.opacity(0.3))

                    Text(LocalizedStringKey(announcement.contentKey))
                        .font(.omyuBody)
                        .foregroundStyle(.white)
                        .lineSpacing(8)
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AnnouncementDetailView(announcement: Announcement.announcements[0])
    }
}
