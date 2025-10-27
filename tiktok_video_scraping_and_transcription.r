# ======================================================================
# TIKTOK VIDEO SCRAPING & TRANSCRIPTION PIPELINE
# ======================================================================
#
# Description: Pipeline for scraping TikTok videos via Apify API,
#              downloading content, and generating transcripts using OpenAI's 
#              Whisper transcription model.
# Author: Ashley Currie
# Portfolio: https://github.com/ashcurrie8
# Date: March 2025
#
# PREREQUISITES:
# 1. Git: Required for Whisper installation
#    - Download from: https://git-scm.com/downloads
#    - Whisper installation via pip requires Git for cloning the repository
#
# 2. FFmpeg: Required for audio processing
#    - Download from: https://ffmpeg.org/download.html
#    - Windows: Extract to C:\ffmpeg and add to system PATH
#    - Whisper uses FFmpeg to extract audio from video files
#
# 3. Apify Account: Required for API access
#    - Sign up at: https://apify.com/
#    - Get API token from: https://console.apify.com/settings/integrations
#
# 4. Environment Variables:
#    - Set APIFY_TOKEN in your .Renviron file
#    - Run: usethis::edit_r_environ()
#    - Add: APIFY_TOKEN=your_actual_token_here

# ======================================================================
# CONFIGURATION
# ======================================================================

# --- Paths ---
WORKING_DIR <- "D:/R video analysis"

# --- Apify API ---
APIFY_ACTOR_ID <- "OtzYfK1ndEGdwWFKQ"

# --- Scraping Parameters ---
HASHTAG <- "YOUR_KEYWORD-HERE"
MAX_RESULTS <- 100 #change to fit data set size you want, or to fit your system capabilities

# --- Whisper Model ---
# Options: "tiny" (fastest), "base", "small", "medium", "large" (most accurate)
WHISPER_MODEL <- "tiny"

# --- Processing ---
PARALLEL_DOWNLOAD <- TRUE
PARALLEL_TRANSCRIPTION <- FALSE  # Memory intensive, keep disabled for most systems

# ======================================================================
# DEPENDENCIES
# ======================================================================

required_packages <- c(
  "httr",      # API requests
  "jsonlite",  # JSON handling
  "purrr",     # Functional programming
  "dplyr",     # Data manipulation
  "reticulate", # Python integration
  "future",    # Parallel processing
  "furrr"      # Parallel mapping
)

# Install missing packages
install_missing_packages <- function(packages) {
  missing <- packages[!packages %in% installed.packages()]
  if (length(missing) > 0) {
    message("Installing missing packages: ", paste(missing, collapse = ", "))
    install.packages(missing)
  }
}

install_missing_packages(required_packages)

# Load libraries
library(httr)
library(jsonlite)
library(purrr)
library(dplyr)
library(reticulate)
library(future)
library(furrr)

# ======================================================================
# INITIALIZATION
# ======================================================================

# Validate environment
validate_environment <- function() {
  # Check working directory
  if (!dir.exists(WORKING_DIR)) {
    stop("Working directory not found: ", WORKING_DIR)
  }
  
  # Check API token
  apify_token <- Sys.getenv("APIFY_TOKEN")
  if (apify_token == "") {
    stop("APIFY_TOKEN environment variable not set. Add it to your .Renviron file.")
  }
  
  message("✓ Environment validation passed")
  return(apify_token)
}

# Initialize workspace
initialize_workspace <- function() {
  dir.create(WORKING_DIR, showWarnings = FALSE, recursive = TRUE)
  setwd(WORKING_DIR)
  dir.create("videos", showWarnings = FALSE)
  dir.create("transcriptions", showWarnings = FALSE)
  
  # Configure parallel processing
  plan(multisession)
  
  message("✓ Workspace initialized: ", WORKING_DIR)
}

# ======================================================================
# PYTHON ENVIRONMENT SETUP
# ======================================================================

setup_python_environment <- function() {
  message("Setting up Python environment for Whisper...")
  
  # Use system Python (modify path if needed)
  python_path <- "C:/Users/ashcu/anaconda3/python.exe"
  use_python(python_path, required = TRUE)
  
  # Install compatible package versions to avoid conflicts, 
  #  Whisper requires an older version of numpy 
  packages <- c(
    "numpy==1.24.3",
    "openai-whisper==20231117",
    "ffmpeg-python==0.2.0"
  )
  
  for (pkg in packages) {
    message("Installing: ", pkg)
    system(paste("pip install", pkg))
  }
  
  # Install PyTorch (CPU-only for stability)
  system("pip install torch==2.0.1 torchaudio==2.0.2 --index-url https://download.pytorch.org/whl/cpu")
  
  # Test installation
  whisper <- import("whisper")
  model <- whisper$load_model(WHISPER_MODEL)
  
  message("✓ Python environment ready - Whisper model loaded: ", WHISPER_MODEL)
  return(list(whisper = whisper, model = model))
}

# ======================================================================
# APIFY INTEGRATION
# ======================================================================

create_apify_payload <- function(hashtag = HASHTAG, results = MAX_RESULTS) {
  list(
    excludePinnedPosts = FALSE,
    hashtags = list(hashtag),
    resultsPerPage = results,
    shouldDownloadCovers = FALSE,
    shouldDownloadSlideshowImages = FALSE,
    shouldDownloadSubtitles = FALSE,
    shouldDownloadVideos = TRUE,
    videoKvStoreIdOrName = "videos"
  )
}

run_apify_actor <- function(apify_token) {
  message("Starting Apify scrape for hashtag: #", HASHTAG)
  
  payload <- create_apify_payload()
  
  response <- POST(
    url = paste0("https://api.apify.com/v2/acts/", APIFY_ACTOR_ID, "/runs"),
    add_headers(
      Authorization = paste0("Bearer ", apify_token),
      "Content-Type" = "application/json"
    ),
    body = toJSON(payload, auto_unbox = TRUE),
    encode = "json"
  )
  
  if (http_error(response)) {
    stop("API request failed: ", content(response, "text"))
  }
  
  run_id <- content(response)$data$id
  message("✓ Scrape initiated - Run ID: ", run_id)
  
  # Wait for completion
  message("Waiting for scrape to complete...")
  while (content(GET(
    paste0("https://api.apify.com/v2/actor-runs/", run_id),
    add_headers(Authorization = paste0("Bearer ", apify_token))
  ))$data$status != "SUCCEEDED") {
    Sys.sleep(5)
  }
  
  # Retrieve results
  video_data <- GET(
    paste0("https://api.apify.com/v2/actor-runs/", run_id, "/dataset/items"),
    add_headers(Authorization = paste0("Bearer ", apify_token))
  ) %>% 
    content("text") %>% 
    fromJSON()
  
  message("✓ Scrape completed - Retrieved ", nrow(video_data), " videos")
  return(video_data)
}

# ======================================================================
# VIDEO DOWNLOAD
# ======================================================================

download_video <- function(url, index, base_path = WORKING_DIR) {
  video_dir <- file.path(base_path, "videos")
  safe_index <- stringr::str_pad(index, width = 4, pad = "0")
  video_path <- file.path(video_dir, paste0("video_", safe_index, ".mp4"))
  
  # Skip if already downloaded
  if (file.exists(video_path)) {
    return(list(success = TRUE, path = video_path, index = index))
  }
  
  tryCatch({
    download.file(url, video_path, mode = "wb", quiet = TRUE)
    list(success = TRUE, path = video_path, index = index)
  }, error = function(e) {
    list(success = FALSE, error = e$message, index = index)
  })
}

download_all_videos <- function(video_data) {
  urls <- video_data$mediaUrls
  total_videos <- length(urls)
  
  message("Downloading ", total_videos, " videos...")
  
  if (PARALLEL_DOWNLOAD) {
    results <- future_map(seq_along(urls), function(i) {
      download_video(urls[[i]], i)
    }, .options = furrr_options(seed = TRUE))
  } else {
    results <- map(seq_along(urls), function(i) {
      message("Downloading video ", i, "/", total_videos)
      download_video(urls[[i]], i)
    })
  }
  
  # Process results
  successes <- keep(results, ~ .x$success)
  failures <- discard(results, ~ .x$success)
  
  if (length(failures) > 0) {
    message("Failed downloads: ", length(failures))
  }
  
  message("✓ Successfully downloaded ", length(successes), "/", total_videos, " videos")
  
  # Add paths to dataset
  video_data$video_path <- NA_character_
  walk(successes, ~ { video_data$video_path[.x$index] <<- .x$path })
  
  saveRDS(video_data, "video_dataset.rds")
  return(video_data)
}

# ======================================================================
# TRANSCRIPTION
# ======================================================================

transcribe_video <- function(model, video_path, index, trans_dir) {
  tryCatch({
    if (!file.exists(video_path)) {
      return(list(success = FALSE, error = "File missing", index = index))
    }
    
    transcription <- model$transcribe(video_path, fp16 = FALSE)
    
    # Save individual transcript
    trans_path <- file.path(trans_dir, paste0("transcript_", index, ".txt"))
    writeLines(transcription$text, trans_path)
    
    list(
      success = TRUE, 
      index = index, 
      text = transcription$text,
      language = transcription$language
    )
  }, error = function(e) {
    list(success = FALSE, error = e$message, index = index)
  })
}

transcribe_all_videos <- function(video_data, whisper_model) {
  valid_idx <- which(!is.na(video_data$video_path))
  total_videos <- length(valid_idx)
  
  if (total_videos == 0) {
    message("No videos available for transcription")
    return(list(successes = list(), video_data = video_data))
  }
  
  message("Transcribing ", total_videos, " videos...")
  
  trans_dir <- file.path(WORKING_DIR, "transcriptions")
  
  if (PARALLEL_TRANSCRIPTION) {
    plan(multisession, workers = min(2, availableCores() - 1))
    results <- future_map(valid_idx, function(i) {
      transcribe_video(whisper_model, video_data$video_path[i], i, trans_dir)
    })
  } else {
    results <- map(valid_idx, function(i) {
      message("Transcribing video ", match(i, valid_idx), "/", total_videos)
      transcribe_video(whisper_model, video_data$video_path[i], i, trans_dir)
    })
  }
  
  successes <- keep(results, ~ .x$success)
  failures <- discard(results, ~ .x$success)
  
  if (length(failures) > 0) {
    message("Failed transcriptions: ", length(failures))
  }
  
  message("✓ Successfully transcribed ", length(successes), "/", total_videos, " videos")
  return(list(successes = successes, video_data = video_data))
}

# ======================================================================
# DATA EXPORT
# ======================================================================

merge_and_export <- function(transcription_results) {
  video_data <- transcription_results$video_data
  successes <- transcription_results$successes
  
  # Add transcription data
  video_data$transcription_text <- NA_character_
  video_data$transcription_language <- NA_character_
  
  walk(successes, ~ {
    video_data$transcription_text[.x$index] <<- .x$text
    video_data$transcription_language[.x$index] <<- .x$language
  })
  
  # Save full dataset
  saveRDS(video_data, "merged_dataset.rds")
  
  # Create analysis-ready dataset, change to fit what you need, check merged_dataset for reference
  analysis_data <- video_data %>% 
    select(
      id, text, createTimeISO, 
      diggCount, shareCount, playCount, collectCount, commentCount,
      transcription_text, transcription_language
    )
  
  write.csv(analysis_data, "analysis_dataset.csv", row.names = FALSE)
  
  message("✓ Data exported:")
  message("  - Full dataset: merged_dataset.rds")
  message("  - Analysis dataset: analysis_dataset.csv")
  
  return(analysis_data)
}

# ======================================================================
# MAIN EXECUTION
# ======================================================================

main <- function() {
  message("Starting TikTok Scraping & Transcription Pipeline")
  message("=================================================")
  
  tryCatch({
    # Setup
    apify_token <- validate_environment()
    initialize_workspace()
    python_env <- setup_python_environment()
    
    # Scraping & Download
    video_data <- run_apify_actor(apify_token)
    video_data <- download_all_videos(video_data)
    
    # Transcription
    transcription_results <- transcribe_all_videos(video_data, python_env$model)
    
    # Export
    final_data <- merge_and_export(transcription_results)
    
    message("\n🎉 PIPELINE COMPLETED SUCCESSFULLY!")
    message("📊 Videos processed: ", nrow(final_data))
    message("📝 Videos transcribed: ", sum(!is.na(final_data$transcription_text)))
    message("💾 Output: analysis_dataset.csv")
    
  }, error = function(e) {
    message("❌ PIPELINE FAILED: ", e$message)
  })
}

# Execute pipeline
main()