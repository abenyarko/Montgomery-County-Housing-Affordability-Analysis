# Phase 1: GitHub Connection Verification
# ----------------------------------------

# 1. Check Git version
system("git --version")

# 2. Check Git status
system("git status")

# 3. Check GitHub remote connection
system("git remote -v")

# 4. Check current Git branch
system("git branch --show-current")

# 5. Check Git user configuration
system("git config --global user.name")
system("git config --global user.email")

# Configure your Git identity
system('git config --global user.name "Anthony Benyarko"')

# Replace the email below with your GitHub email
system('git config --global user.email "abenyarko@gmail.com"')

# Verify configuration
system("git config --global user.name")

system("git config --global user.email")

getwd()

folders <- c(
  "R",
  "data",
  "docs",
  "images"
)

invisible(lapply(
  folders,
  dir.create,
  recursive = TRUE,
  showWarnings = FALSE
))

# Current working directory
getwd()

# Verify project folders
data.frame(
  Folder = folders,
  Exists = dir.exists(folders)
)

# Create a placeholder file in each folder
for (folder in folders) {
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
  
  file.create(file.path(folder, ".gitkeep"))
}

# Verify the files exist
list.files(
  recursive = TRUE,
  all.files = TRUE
)

system("git status")
system("git status")

system("git add R/ data/ images/")

system('git commit -m "Initialize PCC analytics project folder structure"')

system("git push origin main")

# Check whether Git is ignoring the docs folder
system("git check-ignore -v docs/.gitkeep")

# Check current repository status
system("git status")

# Open the existing .gitignore file
file.edit(".gitignore")


