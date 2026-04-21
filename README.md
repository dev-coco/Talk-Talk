# Talk Talk

Talk Talk is a minimalist voice input enhancement tool designed for macOS. It can be triggered via a global shortcut and integrates speech recognition, intelligent correction, and automatic translation, with results pasted directly into the active input field.

## Features

### Shortcut Activation
- **Custom Key Binding**: Supports recording modifier keys such as Fn, Cmd, and Shift as global triggers.  
- **Hold to Speak**: Press to start recording, release to instantly complete recognition and paste the result.  
- **Toggle Mode**: Press once to start and again to stop, ideal for longer dictation sessions.  

### Intelligent Correction
- **Custom Vocabulary Injection**: Allows manual addition of technical terms, proper nouns, or specific vocabulary.  
- **Phonetic Correction**: Uses phonetic similarity algorithms to automatically fix homophones in recognition results based on the custom vocabulary.  

### Translation & Pasting
- **Automatic Translation**: Supports real-time translation into over a dozen languages, including English, Japanese, French, and Spanish.  
- **Auto Paste**: After recognition or translation, the result is copied to the clipboard and automatically pasted at the cursor using `Command + V`.  

### System Integration
- **Launch at Login**: Supports automatic startup via SMAppService.  
- **Multilingual Support**: Allows automatic detection of system languages or manual selection.  
- **Offline Recognition**: Built on the native macOS Speech framework, supporting offline recognition and automatic punctuation.  

## Permissions

The following permissions are required before use:
- **Microphone**: To capture voice input.  
- **Speech Recognition**: To access the system SFSpeech engine.  
- **Accessibility**: To enable automatic text pasting functionality.  