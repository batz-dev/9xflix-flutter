# 🎬 FlixDirect — Modern Flutter Movie Streaming & Downloader

A high-performance, dark-themed Flutter Android application that brings the full power of **9xflix** directly to mobile with **automated ad/shortener bypass**, **direct Cloudflare R2 CDN link resolution**, and a **built-in high-speed download manager**.

---

## ✨ Key Features

1. **🎬 Latest Discovery & Feed:**
   - Cinematic Netflix/Prime-style dark theme (`#0A0A0F`).
   - Spotlight Hero Carousel showcasing the newest blockbusters.
   - Categorized rails: **All, 1080p, 720p, HDTC, Web Series, Dual Audio**.
   - Dynamic quality badges (`HDTC` Theater Print warnings, `1080p`, `720p`, `BluRay`, `WEB-DL`).
   - Infinite scroll pagination and pull-to-refresh.

2. **🔍 Smart Search Engine:**
   - Instant search across movies, seasons, and dual audio.
   - Typo-tolerance suggestions ("Showing results for *Deadpool*").
   - Quick search chips for top trending franchises.

3. **📄 Movie Details Screen:**
   - Clean movie title & release year parsing.
   - IMDb rating badge, Genres, and Audio languages chips.
   - Director, Full Cast & Crew, and expandable storyline overview.
   - **Real Screenshots Gallery:** Uncropped screenshots preview with tap-to-open pinch-to-zoom Lightbox (`InteractiveViewer`).
   - **Granular Download Cards:** Granular 1080p, 720p, and 480p options with file size tags (e.g. `[1.2 GB]`).

4. **⚡ Automated Cloudflare R2 Link Resolver:**
   - Automatically queries Indishare mirror-link backend APIs for DriveHub.
   - Bypasses shorteners, timers, and popups.
   - Resolves direct pre-signed **Cloudflare R2 Object Store CDN** links for instant, maximum-speed downloads.
   - Resolves fast alternative mirrors (**Gofile, VikingFile, FilePress, UploadHub**).

5. **📥 Robust Built-In Download Manager:**
   - Chunked streaming downloads powered by `Dio`.
   - Real-time progress bar, percentage, received/total bytes, and live speed meter (`MB/s` / `KB/s`).
   - **Pause, Resume, and Cancel** support with resume range headers.
   - Saves directly to the public device directory (`/Download/FlixDirect`).
   - **1-Click Video Playback:** Tap play on any completed download to launch in your favorite video player (VLC, MX Player, or gallery).
   - Local persistence via `SharedPreferences`.

6. **⚙️ Settings & Watchlist:**
   - Bookmark movies to offline watchlist.
   - Configure custom 9xflix mirror domains if ISP blocks default.
   - Optional custom self-hosted Flask API endpoint toggle.

---

## 🏗️ Architecture & Project Structure

```
flix_app/
├── lib/
│   ├── main.dart                      # App entry point, MultiProvider & theme init
│   ├── constants/
│   │   └── app_theme.dart             # Dark cinematic design system & typography
│   ├── models/
│   │   ├── movie.dart                 # Movie card item model
│   │   ├── movie_details.dart         # Full movie metadata, synopsis & screenshots
│   │   ├── download_option.dart       # Resolution, file size & intermediate links
│   │   ├── mirror_links.dart          # Resolved Cloudflare R2 & mirror URLs
│   │   └── download_item.dart         # Download task state, speed & disk path
│   ├── services/
│   │   ├── scraper_service.dart       # Pure Dart 9xflix scraper & resolver
│   │   ├── download_manager.dart      # Dio chunked downloader with resume & speed tracking
│   │   └── storage_service.dart       # Watchlist, search history & settings persistence
│   ├── providers/
│   │   └── movies_provider.dart       # Discovery, search, and resolver state management
│   ├── screens/
│   │   ├── main_screen.dart           # BottomNavigationBar with active download count badge
│   │   ├── home_screen.dart           # Discovery feed, categories & hero spotlight
│   │   ├── search_screen.dart         # Typo-tolerant search & trending chips
│   │   ├── movie_details_screen.dart  # Full info, screenshots zoom, download options
│   │   ├── downloads_screen.dart      # Active downloading tab & completed playback tab
│   │   └── settings_screen.dart       # Watchlist & network mirror settings
│   └── widgets/
│       ├── movie_card.dart            # Poster card with quality tags
│       ├── hero_banner.dart           # Spotlight banner widget
│       ├── quality_badge.dart         # HDTC, 1080p, 720p badges
│       ├── screenshot_lightbox.dart   # Fullscreen zoomable screenshot viewer
│       └── download_bottom_sheet.dart # Live mirror resolver & 1-click download drawer
└── .github/workflows/
    └── build-apk.yml                  # GitHub Actions automated release APK build
```

---

## 🚀 Running the App

```bash
cd flix_app
flutter pub get
flutter run
```

To build a standalone release APK:

```bash
flutter build apk --release
```
The compiled APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`
