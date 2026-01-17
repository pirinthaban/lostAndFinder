import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Cloud Function triggered when a new message is added to a chat
 * Sends push notification to the recipient
 */
export const onNewMessage = functions.firestore
    .document('chats/{chatId}/messages/{messageId}')
    .onCreate(async (snapshot, context) => {
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

            const participants: string[] = chatData.participants || [];
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
            const senderName = senderData?.name ||
                senderData?.email?.split('@')[0] ||
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
            const fcmToken = recipientData?.fcmToken;

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
            const notification: admin.messaging.Message = {
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
        } catch (error) {
            console.error('❌ Error sending notification:', error);
            return { success: false, error: String(error) };
        }
    });
