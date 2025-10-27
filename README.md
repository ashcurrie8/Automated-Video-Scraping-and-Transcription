# TikTok Video Scraping & Transcription Pipeline

An end-to-end data pipeline for scraping TikTok videos and generating automated transcripts using OpenAI's Whisper model.
While this version focuses on TikTok, you can modify the code to work for other platforms based on the Apify API you're using!

## 🚀 Overview

This project provides a complete workflow for:
- **Scraping** TikTok videos by hashtag using the Apify API
- **Downloading** video content efficiently with parallel processing
- **Transcribing** audio content using OpenAI's Whisper AI model
- **Exporting** structured data for analysis with video metadata and transcripts

Useful for social media analysis, content research, and qualitative data collection.

## 🎓 Background

This project originated as my final project for **Advanced Political Methodology**, one of the final courses I took as part of my Political Science MA program.

What started as an academic project has been refined into a tool that bridges political science research needs with modern data engineering practices.

## 📋 Prerequisites

Before using this pipeline, ensure you have the following installed:

### 1. Git - Whisper installation requires Git for cloning the repository
- **Download**: https://git-scm.com/install

### 2. FFmpeg - Whisper uses FFmpeg to extract audio from video files
- **Download**: https://ffmpeg.org/download.html
- **Windows Setup**:
  1. Download the Windows build
  2. Extract to `C:\ffmpeg`
  3. Add `C:\ffmpeg\bin` to your system PATH

### 3. Apify Account - Required for accessing TikTok scraping capabilities
- **Sign up**: https://apify.com/
- **Get API Token**: https://console.apify.com/settings/integrations

### 4. Environment Setup
Set your Apify API token as an environment variable:

```r
# Run in R console:
usethis::edit_r_environ()
# Add this line to the file:
APIFY_TOKEN=your_actual_token_here
# Restart RStudio
```

## 🛠️ Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/ashcurrie8/tiktok-transcription-pipeline.git
   cd tiktok-transcription-pipeline
   ```

2. **Run the main script**
   ```r
   # The script will automatically install required R packages
   source("tiktok_video_scraping_and_transcription.r")
   ```

## ⚙️ Configuration

Edit the configuration section at the top of the script:

```r
# --- Paths ---
WORKING_DIR <- "D:/R video analysis"  # Change to your preferred directory

# --- Scraping Parameters ---
HASHTAG <- "YOUR_KEYWORD_HERE"        # Change to your target hashtag
MAX_RESULTS <- 100                    # Adjust based on your needs

# --- Whisper Model ---
WHISPER_MODEL <- "tiny"               # Options: "tiny", "base", "small", "medium", "large"

# --- Processing ---
PARALLEL_DOWNLOAD <- TRUE             # Enable parallel video downloading
PARALLEL_TRANSCRIPTION <- FALSE       # Keep disabled for most systems (memory intensive)
```

## 📁 Project Structure

```
tiktok-transcription-pipeline/
├── tiktok_video_scraping_and_transcription.r  # Main pipeline script
├── README.md                                  # This file
└── (Generated during execution)
    ├── videos/                                # Downloaded video files
    ├── transcriptions/                        # Individual transcript files
    ├── video_dataset.rds                      # Intermediate dataset with video paths
    ├── merged_dataset.rds                     # Complete dataset with transcripts
    └── analysis_dataset.csv                   # Final CSV, you can customize which fields to keep
```

## 🎯 Usage

1. **Configure** the script with your target hashtag and settings
2. **Run** the main script in RStudio
3. **Monitor** the progress through console messages
4. **Analyze** the output in `analysis_dataset.csv`

The pipeline will:
- Validate your environment and dependencies
- Scrape TikTok videos for the specified hashtag
- Download videos to the `videos/` directory
- Transcribe audio content using Whisper AI
- Export a comprehensive dataset with metadata and transcripts

## 📊 Output Data

The final `analysis_dataset.csv` includes:

| Column | Description |
|--------|-------------|
| `id` | Unique TikTok video ID |
| `text` | Video description/caption |
| `createTimeISO` | Upload timestamp |
| `diggCount` | Like count |
| `shareCount` | Share count |
| `playCount` | View count |
| `collectCount` | Save count |
| `commentCount` | Comment count |
| `transcription_text` | AI-generated transcript |
| `transcription_language` | Detected language |

The names of these columns may be different if you use a different Apify API. 
Check the API documentation and/or the `merged_dataset.rds` file to get the correct column names or update which columns you'd like to keep.

## 🔧 Technical Details

### Built With
- **R**: Data processing and pipeline orchestration
- **Python**: Running Whisper AI transcription model
- **Apify API**: TikTok data scraping
- **FFmpeg**: Audio processing
- **Parallel Processing**: Efficient video downloading

### Key Features
- **Automated Pipeline**: End-to-end processing from scrape to ready to use data set
- **Error Handling**: Robust error handling with detailed logging
- **Memory Management**: Optimized for large datasets
- **Flexible Configuration**: Easy customization for different research needs
- **Progress Tracking**: Real-time progress updates during execution

## ⚠️ Important Notes

- **System Resources**: Transcription is computationally intensive. Start with the "tiny" model and small datasets
- **API Limits**: Be mindful of Apify API usage limits and costs
- **Storage**: Video files require significant disk space, I recommend using an external hard drive
- **Legal**: Ensure compliance with TikTok's TOS and applicable laws

## 🐛 Troubleshooting

### Common Issues

1. **Python/Whisper Installation Failures**
   - Ensure Git and FFmpeg are properly installed
   - Check Python path in configuration

2. **API Errors**
   - Verify `APIFY_TOKEN` is set in environment variables
   - Check Apify account balance and permissions

3. **Memory Issues**
   - Set `PARALLEL_TRANSCRIPTION <- FALSE`
   - Reduce `MAX_RESULTS`
   - Use smaller Whisper models

## 📄 License

This project is intended for educational and research purposes. Users are responsible for complying with TikTok's Terms of Service and all applicable laws.

## 👤 Author

**Ashley Currie**
- GitHub: [@ashcurrie8](https://github.com/ashcurrie8)

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the issues page.

---

**Note**: This tool is for research and educational purposes. Always respect platform terms of service and privacy considerations when scraping data.
