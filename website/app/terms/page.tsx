"use client";

import { motion } from "framer-motion";
import { FileText, AlertCircle, CheckCircle, XCircle } from "lucide-react";

export default function Terms() {
  return (
    <div className="pt-24 pb-20 px-6">
      <div className="max-w-4xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-16"
        >
          <div className="inline-flex items-center justify-center w-16 h-16 bg-primary-100 dark:bg-primary-900/30 rounded-2xl mb-6">
            <FileText className="w-8 h-8 text-primary-600 dark:text-primary-400" />
          </div>
          <h1 className="text-5xl font-bold mb-4">Terms of Service</h1>
          <p className="text-xl text-gray-600 dark:text-gray-400">
            Last updated: February 19, 2026
          </p>
        </motion.div>

        {/* Introduction */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="prose prose-lg dark:prose-invert max-w-none mb-12"
        >
          <p className="text-lg text-gray-700 dark:text-gray-300 leading-relaxed">
            Welcome to Simon AI Coach. By accessing or using our mobile application, you agree to be bound by these Terms of Service. Please read them carefully before using the app.
          </p>
        </motion.div>

        {/* Sections */}
        <div className="space-y-12">
          {sections.map((section, index) => (
            <motion.section
              key={index}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 + index * 0.1 }}
              className="p-8 bg-white dark:bg-gray-800 rounded-2xl shadow-lg"
            >
              <div className="flex items-center gap-3 mb-4">
                <section.icon className="w-6 h-6 text-primary-600 dark:text-primary-400" />
                <h2 className="text-2xl font-bold">{section.title}</h2>
              </div>
              <div className="space-y-4 text-gray-700 dark:text-gray-300">
                {section.content.map((paragraph, pIndex) => (
                  <div key={pIndex}>
                    {"subtitle" in paragraph && paragraph.subtitle && (
                      <h3 className="font-semibold text-lg mb-2">{paragraph.subtitle}</h3>
                    )}
                    <p className="leading-relaxed">{paragraph.text}</p>
                    {"list" in paragraph && paragraph.list && (
                      <ul className="list-disc list-inside space-y-1 ml-4 mt-2">
                        {paragraph.list.map((item, iIndex) => (
                          <li key={iIndex}>{item}</li>
                        ))}
                      </ul>
                    )}
                  </div>
                ))}
              </div>
            </motion.section>
          ))}
        </div>

        {/* Contact */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.8 }}
          className="mt-16 p-8 bg-gradient-to-br from-primary-50 to-purple-50 dark:from-primary-900/20 dark:to-purple-900/20 rounded-2xl text-center"
        >
          <h2 className="text-2xl font-bold mb-4">Questions About These Terms?</h2>
          <p className="text-gray-700 dark:text-gray-300 mb-6">
            If you have questions about these Terms of Service, please contact us:
          </p>
          <a
            href="mailto:legal@simonaicoach.com"
            className="inline-block px-6 py-3 bg-primary-600 hover:bg-primary-700 text-white rounded-full font-semibold transition-all"
          >
            legal@simonaicoach.com
          </a>
        </motion.div>
      </div>
    </div>
  );
}

const sections = [
  {
    icon: CheckCircle,
    title: "Acceptance of Terms",
    content: [
      {
        text: "By creating an account or using Simon AI Coach, you agree to these Terms of Service and our Privacy Policy. If you do not agree, you may not use the app.",
      },
      {
        text: "You must be at least 13 years old to use this app. If you are under 18, you must have permission from a parent or guardian.",
      },
    ],
  },
  {
    icon: FileText,
    title: "Account Registration",
    content: [
      {
        text: "To use Simon AI Coach, you must create an account using Google Sign-In or Apple Sign-In. You agree to:",
        list: [
          "Provide accurate and complete information",
          "Maintain the security of your account",
          "Notify us immediately of any unauthorized access",
          "Be responsible for all activity under your account",
        ],
      },
      {
        text: "We reserve the right to suspend or terminate accounts that violate these terms.",
      },
    ],
  },
  {
    icon: AlertCircle,
    title: "Subscription and Payments",
    content: [
      {
        subtitle: "Free Tier",
        text: "The free tier includes 3 messages per coaching session. You can start unlimited sessions.",
      },
      {
        subtitle: "Pro Subscription",
        text: "Pro subscriptions are available as:",
        list: [
          "Weekly: $9.99/week",
          "Monthly: $29.99/month",
          "Yearly: $79.99/year",
        ],
      },
      {
        text: "All subscriptions are processed through the Apple App Store. Payments are charged to your Apple ID account. Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period.",
      },
      {
        subtitle: "Refunds",
        text: "Refund requests must be made through Apple. We do not process refunds directly. Contact Apple Support for refund inquiries.",
      },
      {
        subtitle: "Cancellation",
        text: "You can cancel your subscription at any time through your Apple ID settings. You will retain Pro access until the end of your billing period.",
      },
    ],
  },
  {
    icon: XCircle,
    title: "Acceptable Use",
    content: [
      {
        text: "You agree NOT to:",
        list: [
          "Use the app for illegal purposes",
          "Harass, abuse, or harm others",
          "Attempt to hack, reverse engineer, or compromise the app",
          "Upload malicious content or viruses",
          "Impersonate others or create fake accounts",
          "Scrape or collect data without permission",
          "Use the app to generate spam or harmful content",
        ],
      },
      {
        text: "Violation of these terms may result in immediate account termination.",
      },
    ],
  },
  {
    icon: AlertCircle,
    title: "AI-Generated Content",
    content: [
      {
        text: "Simon AI Coach uses artificial intelligence to generate coaching responses. You acknowledge that:",
        list: [
          "AI responses are not professional medical, legal, or financial advice",
          "AI may occasionally produce inaccurate or inappropriate content",
          "You should verify important information independently",
          "We are not liable for decisions made based on AI responses",
        ],
      },
      {
        text: "If you need professional advice, please consult a qualified professional.",
      },
    ],
  },
  {
    icon: FileText,
    title: "Intellectual Property",
    content: [
      {
        subtitle: "Our Content",
        text: "The app, including its design, code, and curated coaches, is owned by Simon AI Coach and protected by copyright and trademark laws.",
      },
      {
        subtitle: "Your Content",
        text: "You retain ownership of content you create (custom coaches, messages, plans). By using the app, you grant us a license to:",
        list: [
          "Store and process your content to provide the service",
          "Display your published coaches to other users (if you choose to publish)",
          "Use anonymized data to improve the app",
        ],
      },
      {
        text: "You can delete your content at any time through the app.",
      },
    ],
  },
  {
    icon: XCircle,
    title: "Disclaimers and Limitations",
    content: [
      {
        text: 'The app is provided "as is" without warranties of any kind. We do not guarantee:',
        list: [
          "Uninterrupted or error-free service",
          "Accuracy or reliability of AI responses",
          "Specific results or outcomes",
          "Compatibility with all devices",
        ],
      },
      {
        text: "To the maximum extent permitted by law, we are not liable for:",
        list: [
          "Indirect, incidental, or consequential damages",
          "Loss of data, profits, or business opportunities",
          "Damages resulting from AI-generated content",
          "Third-party actions or content",
        ],
      },
      {
        text: "Our total liability is limited to the amount you paid in the past 12 months.",
      },
    ],
  },
  {
    icon: AlertCircle,
    title: "Termination",
    content: [
      {
        text: "You may terminate your account at any time by:",
        list: [
          "Going to Settings → Account → Delete Account",
          "Emailing support@simonaicoach.com",
        ],
      },
      {
        text: "We may suspend or terminate your account if you:",
        list: [
          "Violate these Terms of Service",
          "Engage in fraudulent activity",
          "Abuse the service or other users",
          "Fail to pay subscription fees",
        ],
      },
      {
        text: "Upon termination, your data will be deleted within 30 days, except as required by law.",
      },
    ],
  },
  {
    icon: FileText,
    title: "Changes to Terms",
    content: [
      {
        text: "We may update these Terms of Service from time to time. We will notify you of significant changes via:",
        list: [
          "In-app notification",
          "Email to your registered address",
          "Update to the 'Last updated' date",
        ],
      },
      {
        text: "Your continued use of the app after changes constitutes acceptance of the updated terms.",
      },
    ],
  },
  {
    icon: AlertCircle,
    title: "Governing Law",
    content: [
      {
        text: "These Terms are governed by the laws of the United States and the State of California, without regard to conflict of law principles.",
      },
      {
        text: "Any disputes will be resolved through binding arbitration in accordance with the rules of the American Arbitration Association.",
      },
    ],
  },
];
