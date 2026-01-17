"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onNewMessage = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
/**
 * Cloud Function triggered when a new message is added to a chat
 * Sends push notification to the recipient
 */
exports.onNewMessage = functions.firestore
    .document('chats/{chatId}/messages/{messageId}')
    .onCreate(async (snapshot, context) => {
    var _a;
    const message = snapshot.data();
    const chatId = context.params.chatId;
    const messageId = context.params.messageId;
    console.log(`💬 New message in chat ${chatId}: ${messageId}`);
    if (!message) {
        console.log('No message data found');
        return null;
    }
    const senderId = message.senderId;
    const messageText = message.text || 'New message';
    try {
        const db = admin.firestore();
        // Get the chat document to find participants
        const chatDoc = await db
            .collection('chats')
            .doc(chatId)
            .get();
        if (!chatDoc.exists) {
            console.log('Chat document not found');
            return null;
        }
        const chatData = chatDoc.data();
        if (!chatData) {
            return null;
        }
        const participants = chatData.participants || [];
        const itemTitle = chatData.itemTitle || '';
        // Find the recipient (the other participant)
        const recipientId = participants.find(p => p !== senderId);
        if (!recipientId) {
            console.log('No recipient found');
            return null;
        }
        // Get sender's name
        const senderDoc = await db
            .collection('users')
            .doc(senderId)
            .get();
        const senderData = senderDoc.data();
        const senderName = (senderData === null || senderData === void 0 ? void 0 : senderData.name) ||
            ((_a = senderData === null || senderData === void 0 ? void 0 : senderData.email) === null || _a === void 0 ? void 0 : _a.split('@')[0]) ||
            'Someone';
        // Get recipient's FCM token
        const recipientDoc = await db
            .collection('users')
            .doc(recipientId)
            .get();
        if (!recipientDoc.exists) {
            console.log('Recipient document not found');
            return null;
        }
        const recipientData = recipientDoc.data();
        const fcmToken = recipientData === null || recipientData === void 0 ? void 0 : recipientData.fcmToken;
        if (!fcmToken) {
            console.log('📭 No FCM token for recipient, saving to Firestore only');
            // Still save notification to Firestore
            await db.collection('notifications').add({
                userId: recipientId,
                title: `💬 ${senderName}`,
                body: messageText.length > 50 ? `${messageText.substring(0, 50)}...` : messageText,
                type: 'chat_message',
                data: {
                    chatId: chatId,
                    senderId: senderId,
                    senderName: senderName,
                    itemTitle: itemTitle,
                },
                read: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            return null;
        }
        // Build notification message
        const notification = {
            token: fcmToken,
            notification: {
                title: `💬 ${senderName}`,
                body: messageText.length > 100
                    ? `${messageText.substring(0, 100)}...`
                    : messageText,
            },
            data: {
                type: 'chat_message',
                chatId: chatId,
                senderId: senderId,
                senderName: senderName,
                itemTitle: itemTitle,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            android: {
                priority: 'high',
                notification: {
                    channelId: 'chat_channel',
                    icon: '@mipmap/ic_launcher',
                    color: '#10B981',
                    sound: 'default',
                },
            },
            apns: {
                payload: {
                    aps: {
                        badge: 1,
                        sound: 'default',
                    },
                },
            },
        };
        // Send the push notification
        const response = await admin.messaging().send(notification);
        console.log(`✅ Push notification sent: ${response}`);
        // Also save notification to Firestore for in-app notification center
        await db.collection('notifications').add({
            userId: recipientId,
            title: `New message from ${senderName}`,
            body: messageText.length > 50 ? `${messageText.substring(0, 50)}...` : messageText,
            type: 'chat_message',
            data: {
                chatId: chatId,
                senderId: senderId,
                senderName: senderName,
                itemTitle: itemTitle,
            },
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { success: true };
    }
    catch (error) {
        console.error('❌ Error sending notification:', error);
        return { success: false, error: String(error) };
    }
});
//# sourceMappingURL=onNewMessage.js.map