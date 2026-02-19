"use client";

import { motion } from "framer-motion";
import { Mail, MessageCircle, Book, HelpCircle } from "lucide-react";

interface FAQ {
  question: string;
  answer: string;
}

export default function Support() {
  return (
    <div className="pt-24 pb-20 px-6">
      <div className="max-w-4xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-16"
        >
          <h1 className="text-5xl font-bold mb-4">Support</h1>
          <p className="text-xl text-gray-600 dark:text-gray-400">
            We're here to help you get the most out of Simon AI Coach
          </p>
        </motion.div>

        {/* Contact Options */}
        <div className="grid md:grid-cols-2 gap-6 mb-16">
          <motion.a
            href="mailto:support@simonaicoach.com"
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.1 }}
            className="p-6 bg-white dark:bg-gray-800 rounded-2xl shadow-lg hover:shadow-xl transition-all group"
          >
            <div className="w-12 h-12 bg-primary-100 dark:bg-primary-900/30 rounded-xl flex items-center justify-center mb-4 group-hover:scale-110 transition-transform">
              <Mail className="w-6 h-6 text-primary-600 dark:text-primary-400" />
            </div>
            <h3 className="text-xl font-semibold mb-2">Email Support</h3>
            <p className="text-gray-600 dark:text-gray-400">
              Get help via email. We typically respond within 24 hours.
            </p>
            <p className="text-primary-600 dark:text-primary-400 mt-2 font-medium">
              support@simonaicoach.com
            </p>
          </motion.a>

          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.2 }}
            className="p-6 bg-white dark:bg-gray-800 rounded-2xl shadow-lg"
          >
            <div className="w-12 h-12 bg-primary-100 dark:bg-primary-900/30 rounded-xl flex items-center justify-center mb-4">
              <MessageCircle className="w-6 h-6 text-primary-600 dark:text-primary-400" />
            </div>
            <h3 className="text-xl font-semibold mb-2">In-App Support</h3>
            <p className="text-gray-600 dark:text-gray-400">
              Access help directly from the app. Go to Settings → Help & Support.
            </p>
          </motion.div>
        </div>

        {/* FAQ Section */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="mb-16"
        >
          <div className="flex items-center gap-3 mb-8">
            <HelpCircle className="w-8 h-8 text-primary-600 dark:text-primary-400" />
            <h2 className="text-3xl font-bold">Frequently Asked Questions</h2>
          </div>

          <div className="space-y-6">
            {faqs.map((faq, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.4 + index * 0.1 }}
                className="p-6 bg-white dark:bg-gray-800 rounded-xl shadow"
              >
                <h3 className="text-lg font-semibold mb-2">{faq.question}</h3>
                <p className="text-gray-600 dark:text-gray-400">{faq.answer}</p>
              </motion.div>
            ))}
          </div>
        </motion.div>

        {/* Getting Started */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.5 }}
          className="p-8 bg-gradient-to-br from-primary-50 to-purple-50 dark:from-primary-900/20 dark:to-purple-900/20 rounded-2xl"
        >
          <div className="flex items-center gap-3 mb-4">
            <Book className="w-8 h-8 text-primary-600 dark:text-primary-400" />
            <h2 className="text-2xl font-bold">Getting Started</h2>
          </div>
          <div className="space-y-4 text-gray-700 dark:text-gray-300">
            <div>
              <h3 className="font-semibold mb-1">1. Sign In</h3>
              <p>Use Google Sign-In to create your account securely.</p>
            </div>
            <div>
              <h3 className="font-semibold mb-1">2. Browse Coaches</h3>
              <p>Explore our curated library of AI coaches or create your own custom coach.</p>
            </div>
            <div>
              <h3 className="font-semibold mb-1">3. Start Chatting</h3>
              <p>Begin a conversation with any coach. You get 3 free messages per session.</p>
            </div>
            <div>
              <h3 className="font-semibold mb-1">4. Upgrade to Pro</h3>
              <p>For unlimited messages and advanced features, upgrade to Simon Pro anytime.</p>
            </div>
          </div>
        </motion.div>

        {/* Subscription Help */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.6 }}
          className="mt-16 p-8 bg-white dark:bg-gray-800 rounded-2xl shadow-lg"
        >
          <h2 className="text-2xl font-bold mb-4">Subscription & Billing</h2>
          <div className="space-y-4 text-gray-600 dark:text-gray-400">
            <p>
              All subscriptions are managed through the App Store. To manage your subscription:
            </p>
            <ol className="list-decimal list-inside space-y-2 ml-4">
              <li>Open the Settings app on your iPhone</li>
              <li>Tap your name at the top</li>
              <li>Tap "Subscriptions"</li>
              <li>Select "Simon AI Coach"</li>
              <li>Manage or cancel your subscription</li>
            </ol>
            <p className="mt-4">
              For billing questions or refund requests, please contact Apple Support or email us at{" "}
              <a href="mailto:support@simonaicoach.com" className="text-primary-600 dark:text-primary-400 hover:underline">
                support@simonaicoach.com
              </a>
            </p>
          </div>
        </motion.div>

        {/* Technical Support */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.7 }}
          className="mt-8 p-8 bg-white dark:bg-gray-800 rounded-2xl shadow-lg"
        >
          <h2 className="text-2xl font-bold mb-4">Technical Issues</h2>
          <div className="space-y-4 text-gray-600 dark:text-gray-400">
            <p>If you're experiencing technical issues, try these steps:</p>
            <ul className="list-disc list-inside space-y-2 ml-4">
              <li>Make sure you're running the latest version of the app</li>
              <li>Check your internet connection</li>
              <li>Restart the app</li>
              <li>Sign out and sign back in</li>
              <li>Restart your device</li>
            </ul>
            <p className="mt-4">
              If the issue persists, please email us at{" "}
              <a href="mailto:support@simonaicoach.com" className="text-primary-600 dark:text-primary-400 hover:underline">
                support@simonaicoach.com
              </a>{" "}
              with details about the problem and your device model.
            </p>
          </div>
        </motion.div>
      </div>
    </div>
  );
}

const faqs: FAQ[] = [
  {
    question: "How does the free tier work?",
    answer: "You get 3 free messages per coaching session with any coach. After that, you can start a new session or upgrade to Pro for unlimited messages.",
  },
  {
    question: "What's included in Simon Pro?",
    answer: "Pro includes unlimited messages with all coaches, the ability to publish custom coaches, voice-over responses, document uploads, all intelligent tools, and priority support.",
  },
  {
    question: "Can I cancel my subscription anytime?",
    answer: "Yes! You can cancel your subscription at any time through the App Store. You'll continue to have Pro access until the end of your billing period.",
  },
  {
    question: "How do I create a custom coach?",
    answer: "Tap the '+' button in the Home tab, fill in your coach's details (name, specialty, style), optionally generate an AI avatar, and tap 'Create Coach'. You can start chatting immediately.",
  },
  {
    question: "Is my data secure?",
    answer: "Yes. All data is encrypted in transit and at rest. We use Firebase Authentication and follow industry best practices for security. We don't sell your data or show ads.",
  },
  {
    question: "Can I use Simon on multiple devices?",
    answer: "Yes! Your account, coaches, conversations, and preferences sync automatically across all your devices via Firebase.",
  },
  {
    question: "What are 'Moments'?",
    answer: "Moments are quick actions for instant guidance. Use pre-built templates or ask anything directly, and you'll be routed to the most appropriate coach automatically.",
  },
  {
    question: "How do voice messages work?",
    answer: "Tap and hold the microphone button to record a voice message. Your coach will transcribe it and respond. With Pro, you can enable voice-over for spoken responses.",
  },
];
