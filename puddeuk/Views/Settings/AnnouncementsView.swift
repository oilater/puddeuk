import SwiftUI

struct AnnouncementsView: View {
    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Announcement.announcements) { announcement in
                        NavigationLink {
                            AnnouncementDetailView(announcement: announcement)
                        } label: {
                            AnnouncementRowView(announcement: announcement)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("announcements.navigation.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AnnouncementRowView: View {
    let announcement: Announcement

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "megaphone.fill")
                    .foregroundStyle(.teal)
                    .font(.omyu(size: 20))

                Text(LocalizedStringKey(announcement.titleKey))
                    .font(.omyuHeadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.gray)
                    .font(.omyu(size: 14))
            }

            Text(announcement.formattedDate)
                .font(.omyuCaption)
                .foregroundStyle(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        AnnouncementsView()
    }
}
