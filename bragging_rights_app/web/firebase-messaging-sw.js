importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js');

// Initialize Firebase in the service worker
// Using your Firebase config from the project
firebase.initializeApp({
  apiKey: "AIzaSyBckWfRIOYJ2qnC6wUWRsKIKQkx3pEUi84",
  authDomain: "bragging-rights-ea6e1.firebaseapp.com",
  projectId: "bragging-rights-ea6e1",
  storageBucket: "bragging-rights-ea6e1.firebasestorage.app",
  messagingSenderId: "747896887728",
  appId: "1:747896887728:web:ed41195d4c6fe8a45c1e75"
});

// Retrieve firebase messaging
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('Received background message: ', payload);
  
  const notificationTitle = payload.notification.title || 'Bragging Rights';
  const notificationOptions = {
    body: payload.notification.body || 'You have a new notification',
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});