importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyAyDvONTHHetrhRz9ZKvfJf2U4aI754gBQ",
  authDomain: "tdigital-56396.firebaseapp.com",
  projectId: "tdigital-56396",
  storageBucket: "tdigital-56396.firebasestorage.app",
  messagingSenderId: "521088896111",
  appId: "1:521088896111:web:bab8e37c62dccf8fbd919a",
  measurementId: "G-ZS1MRSP9XK",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((message) => {
  console.log("Background message:", message);
  const notification = message.notification;
  if (notification) {
    self.registration.showNotification(notification.title, {
      body: notification.body,
      icon: "/icons/Icon-192.png",
    });
  }
});
