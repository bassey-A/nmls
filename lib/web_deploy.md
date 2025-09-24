## Web Deployment via Firebase Hosting


#### Prerequisites
* Flutter SDK: Ensure the Flutter SDK is installed and configured in your system's PATH.

* Node.js and npm: Ensure node.js and npm are installed. You can get them from nodejs.org.

* Firebase Project: Verify that your project (nlms-niger) is set up.


#### Steps
- [x] Enable Web Support for Your Flutter Project
First, you need to tell Flutter to enable web builds and then add the necessary web-specific files to your existing project.

- [x] Enable the web configuration: flutter config --enable-web

- [x] Add web support to your project: Run this command from the root directory of your project (the same folder that contains your pubspec.yaml file): flutter create .

This command will safely add a web folder and other necessary files without overwriting your existing mobile code.

- [x] Install the Firebase CLI: npm install -g firebase-tools

- [x] Log in to Firebase: firebase login

- [x] Initialize Firebase in your project: firebase init hosting

This will start an interactive setup process. Answer the questions as follows:

"Please select an option:" → Choose Use an existing project.

"Select a default Firebase project for this directory:" → Select your project, nlms-niger.

"What do you want to use as your public directory?" → This is the most important step. Type build/web and press Enter. This tells Firebase where to find your app's files after you build them.

"Configure as a single-page app (rewrite all urls to /index.html)?" → Type y and press Enter. This is crucial for Flutter's web routing to work correctly.

"Set up automatic builds and deploys with GitHub?" → Type n and press Enter for now to keep things simple.

This will create two new files in your project: .firebaserc and firebase.json.

- [ ] Run the build command: flutter build web

- [ ] Run the deploy command: firebase deploy


