@ECHO OFF
SETLOCAL EnableDelayedExpansion
REM ========================================
REM PNG Resize Tool for Minecraft Resource Packs
REM ========================================

REM Configuration: Set the scale factor as percentage (50 = half size, 200 = double size)
SET SCALE_PERCENT=50

















REM ██████   ██████       ███    ██  ██████  ████████ 
REM ██   ██ ██    ██      ████   ██ ██    ██    ██    
REM ██   ██ ██    ██      ██ ██  ██ ██    ██    ██    
REM ██   ██ ██    ██      ██  ██ ██ ██    ██    ██    
REM ██████   ██████       ██   ████  ██████     ██    

REM ███████ ██████  ██ ████████      ██████  ███████ ██       ██████  ██     ██ 
REM ██      ██   ██ ██    ██         ██   ██ ██      ██      ██    ██ ██     ██ 
REM █████   ██   ██ ██    ██         ██████  █████   ██      ██    ██ ██  █  ██ 
REM ██      ██   ██ ██    ██         ██   ██ ██      ██      ██    ██ ██ ███ ██ 
REM ███████ ██████  ██    ██         ██████  ███████ ███████  ██████   ███ ███  

REM Check if ImageMagick is installed
where magick >nul 2>&1
IF ERRORLEVEL 1 (
    ECHO ERROR: ImageMagick not found. Please install ImageMagick and add it to your PATH.
    ECHO Download from: https://imagemagick.org/script/download.php
    PAUSE
    EXIT /B 1
)

REM Check if PowerShell is available (for ZIP operations)
where powershell >nul 2>&1
IF ERRORLEVEL 1 (
    ECHO ERROR: PowerShell not found. PowerShell is required for ZIP operations.
    PAUSE
    EXIT /B 1
)

REM Check if a file was dropped on the batch file
IF "%~1"=="" (
    ECHO ERROR: Please drag and drop a ZIP file onto this batch file.
    ECHO The ZIP should contain a resource pack with assets/minecraft/textures structure.
    EXIT /B 1
)

REM Store the dropped file path
SET "INPUT_FILE=%~1"
SET "INPUT_NAME=%~n1"
SET "INPUT_EXT=%~x1"

REM Check if the dropped item is a ZIP file
IF /I NOT "%INPUT_EXT%"==".zip" (
    ECHO ERROR: "%INPUT_FILE%" is not a ZIP file.
    ECHO Please drop a .zip file containing a Minecraft resource pack.
    PAUSE
    EXIT /B 1
)

REM Check if the ZIP file exists
IF NOT EXIST "%INPUT_FILE%" (
    ECHO ERROR: "%INPUT_FILE%" does not exist.
    PAUSE
    EXIT /B 1
)

REM Create temporary extraction directory
SET "TEMP_DIR=%TEMP%\resizepack_%RANDOM%"
SET "OUTPUT_ZIP=%~dp1[RESIZED] %INPUT_NAME%.zip"

ECHO ========================================
ECHO Extracting ZIP file
ECHO ========================================
ECHO Input ZIP: "%INPUT_FILE%"
ECHO Temp folder: "%TEMP_DIR%"
ECHO Output ZIP: "%OUTPUT_ZIP%"
ECHO ========================================
ECHO.

REM Extract the ZIP file
ECHO Extracting ZIP file...
powershell -Command "Expand-Archive -Path '%INPUT_FILE%' -DestinationPath '%TEMP_DIR%' -Force"
IF ERRORLEVEL 1 (
    ECHO ERROR: Failed to extract ZIP file.
    PAUSE
    EXIT /B 1
)

REM If not found in subdirectories, check if extracted directly to temp dir
IF EXIST "%TEMP_DIR%\assets\minecraft\textures\" (
    SET "PACK_FOLDER=%TEMP_DIR%"
    GOTO :found_pack
)

ECHO ERROR: Could not find a valid resource pack structure in the ZIP file.
ECHO Looking for: assets/minecraft/textures/
ECHO.
ECHO Available folders:
DIR "%TEMP_DIR%" /AD /B
ECHO.
PAUSE
RMDIR /S /Q "%TEMP_DIR%" 2>nul
EXIT /B 1

:found_pack

REM Navigate to the textures folder
SET "TEXTURES_FOLDER=%PACK_FOLDER%\assets\minecraft\textures"

ECHO ========================================
ECHO Resizing PNG files in resource pack
ECHO ========================================
ECHO Pack folder: "%PACK_FOLDER%"
ECHO Textures folder: "%TEXTURES_FOLDER%"
ECHO Scale percentage: %SCALE_PERCENT%%%
ECHO ========================================
ECHO.

REM Initialize counters
SET /A PROCESSED=0
SET /A ERRORS=0
SET /A SKIPPED=0

REM Process all PNG files recursively
ECHO Starting resize process...
ECHO.

FOR /R "%TEXTURES_FOLDER%" %%F IN (*.png) DO (
    ECHO Processing: %%~nxF
    
    REM Check if the file is in a colormap folder
    ECHO %%F | FINDSTR /I "\\colormap\\" >nul
    IF NOT ERRORLEVEL 1 (
        ECHO   SKIPPED: %%~nxF - File is in colormap folder
        SET /A SKIPPED+=1
    ) ELSE (
        REM Get the current dimensions for reference
        FOR /F "tokens=1,2" %%A IN ('magick identify -format "%%w %%h" "%%F" 2^>nul') DO (
        SET /A WIDTH=%%A
        SET /A HEIGHT=%%B
        
        REM Check if width and height are a power of 2
        SET /A IS_X_POWER_OF_2=0
        SET /A IS_Y_POWER_OF_2=0
        SET /A TEMP_WIDTH=!WIDTH!
        SET /A TEMP_HEIGHT=!HEIGHT!
        
        REM Check powers of 2 from 1 to 4096
        FOR %%P IN (1 2 4 8 16 32 64 128 256 512 1024 2048 4096) DO (
            IF !TEMP_WIDTH! EQU %%P SET /A IS_X_POWER_OF_2=1
            IF !TEMP_HEIGHT! EQU %%P SET /A IS_Y_POWER_OF_2=1
        )
        
        REM Process if BOTH width AND height are power of 2, OR if BOTH are over 500 pixels
        IF !IS_X_POWER_OF_2! EQU 1 IF !IS_Y_POWER_OF_2! EQU 1 (
            REM Both dimensions are power of 2 - process normally
            SET /A NEW_WIDTH=!WIDTH!*!SCALE_PERCENT!/100
            SET /A NEW_HEIGHT=!HEIGHT!*!SCALE_PERCENT!/100
            
            REM Resize the image in-place using percentage
            magick "%%F" -resize !SCALE_PERCENT!%% "%%F" 2>nul
            
            IF ERRORLEVEL 1 (
                ECHO   ERROR: Failed to resize %%~nxF
                SET /A ERRORS+=1
            ) ELSE (
                ECHO   SUCCESS: !WIDTH! x !HEIGHT! -^> !NEW_WIDTH! x !NEW_HEIGHT!
                SET /A PROCESSED+=1
            )
        ) ELSE (
            REM Check if either dimension is large (over 500px)
            IF !WIDTH! GTR 500 (
                ECHO   PROCESSING: !WIDTH! x !HEIGHT! - Large image ^(width over 500px^)
                SET /A NEW_WIDTH=!WIDTH!*!SCALE_PERCENT!/100
                SET /A NEW_HEIGHT=!HEIGHT!*!SCALE_PERCENT!/100
                
                REM Resize the image in-place using percentage
                magick "%%F" -resize !SCALE_PERCENT!%% "%%F" 2>nul
                
                IF ERRORLEVEL 1 (
                    ECHO   ERROR: Failed to resize %%~nxF
                    SET /A ERRORS+=1
                ) ELSE (
                    ECHO   SUCCESS: !WIDTH! x !HEIGHT! -^> !NEW_WIDTH! x !NEW_HEIGHT!
                    SET /A PROCESSED+=1
                )
            ) ELSE IF !HEIGHT! GTR 500 (
                ECHO   PROCESSING: !WIDTH! x !HEIGHT! - Large image ^(height over 500px^)
                SET /A NEW_WIDTH=!WIDTH!*!SCALE_PERCENT!/100
                SET /A NEW_HEIGHT=!HEIGHT!*!SCALE_PERCENT!/100
                
                REM Resize the image in-place using percentage
                magick "%%F" -resize !SCALE_PERCENT!%% "%%F" 2>nul
                
                IF ERRORLEVEL 1 (
                    ECHO   ERROR: Failed to resize %%~nxF
                    SET /A ERRORS+=1
                ) ELSE (
                    ECHO   SUCCESS: !WIDTH! x !HEIGHT! -^> !NEW_WIDTH! x !NEW_HEIGHT!
                    SET /A PROCESSED+=1
                )
            ) ELSE (
                ECHO   SKIPPED: !WIDTH! x !HEIGHT! - Not power of 2 and not large enough
                SET /A SKIPPED+=1
            )
        )
    )
)
)

ECHO.
ECHO ========================================
ECHO Resize operation completed
ECHO ========================================
ECHO Files processed successfully: %PROCESSED%
ECHO Files skipped (colormap folders and non-power-of-2 under 500px): %SKIPPED%
ECHO Files with errors: %ERRORS%
ECHO Scale percentage used: %SCALE_PERCENT%%%
ECHO ========================================

IF %ERRORS% GTR 0 (
    ECHO WARNING: Some files encountered errors during processing.
)

ECHO.
ECHO ========================================
ECHO Creating output ZIP file
ECHO ========================================
ECHO Output file: "%OUTPUT_ZIP%"
ECHO.

REM Create the output ZIP file
ECHO Creating ZIP file...
powershell -Command "Compress-Archive -Path '%PACK_FOLDER%\*' -DestinationPath '%OUTPUT_ZIP%' -Force"
IF ERRORLEVEL 1 (
    ECHO ERROR: Failed to create output ZIP file.
    PAUSE
    RMDIR /S /Q "%TEMP_DIR%" 2>nul
    EXIT /B 1
)

REM Clean up temporary directory
ECHO Cleaning up temporary files...
RMDIR /S /Q "%TEMP_DIR%" 2>nul

ECHO.
ECHO ========================================
ECHO SUCCESS: ZIP processing completed!
ECHO ========================================
ECHO Input:  "%INPUT_FILE%"
ECHO Output: "%OUTPUT_ZIP%"
ECHO ========================================

ECHO.
ECHO Press any key to close...
PAUSE >nul
