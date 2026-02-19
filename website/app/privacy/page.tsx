"use client";

import { motion } from "framer-motion";
import { Shield, Lock, Eye, Database, UserCheck, FileText } from "lucide-react";

export default function Privacy() {
  return (
    <div className="pt-24 pb-20 px-6">
      <div className="max-w-4xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-16"
        >
          <div className="inline-flex items-center justify-center w-16 h-16 bg-primary-100 dark:bg-primary-900/30 rounded-2xl mb-6">
            <Shield className="w-8 h-8 text-primary-600 dark:text-primary-400" />
          </div>
          <h1 className="text-5xl font-bold mb-4">Privacy Policy</h1>
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
            At Simon AI Coach, we take your privacy seriously. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application. Please read this privacy policy carefully. If you do not agree with the terms of this privacy policy, please do not access the application.
          </p>
        </motion.div>

        {/* Key Principles */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="grid md:grid-cols-3 gap-6 mb-16"
        >
          {principles.map((principle, index) => (
            <div
              key={index}
              className="p-6 bg-white dark:bg-gray-800 rounded-xl shadow-lg text-center"
            >
              <div className="w-12 h-12 bg-primary-100 dark:bg-primary-900/30 rounded-xl flex items-center justify-center mx-auto mb-4">
                <principle.icon className="w-6 h-6 text-primary-600 dark:text-primary-400" />
              </div>
              <h3 className="font-semibold mb-2">{principle.title}</h3>
              <p className="text-sm text-gray-600 dark:text-gray-400">{principle.description}</p>
            </div>
          ))}
        </motion.div>

        {/* Detailed Sections */}
        <div className="space-y-12">
          {sections.map((section, index) => (
            <motion.section
              key={index}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 + index * 0.1 }}
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
          <h2 className="text-2xl font-bold mb-4">Questions About Privacy?</h2>
          <p className="text-gray-700 dark:text-gray-300 mb-6">
            If you have questions or concerns about this Privacy Policy, please contact us:
          </p>
          <a
            href="mailto:privacy@simonaicoach.com"
            className="inline-block px-6 py-3 bg-primary-600 hover:bg-primary-700 text-white rounded-full font-semibold transition-all"
          >
            privacy@simonaicoach.com
          </a>
        </motion.div>
      </div>
    </div>
  );
}

const principles = [
  {
    icon: Lock,
    title: "Encrypted",
    description: "All data is encrypted in transit and at rest using industry standards.",
  },
  {
    icon: Eye,
    title: "No Tracking",
    description: "We don't use third-party analytics or advertising trackers.",
  },
  {
    icon: UserCheck,
    title: "Your Control",
    description: "You can export, view, or delete your data at any time.",
  },
];

const sections = [
  {
    icon: Database,
    title: "Information We Collect",
    content: [
      {
        subtitle: "Account Information",
        text: "When you create an account, we collect:",
        list: [
          "Email address (from Google Sign-In or Apple Sign-In)",
          "Display name and profile photo (optional)",
          "User ID (generated automatically)",
        ],
      },
      {
        subtitle: "Usage Information",
        text: "When you use the app, we collect:",
        list: [
          "Coaching conversations and messages",
          "Custom coaches you create",
          "Plans, reminders, and calendar events you create",
          "Voice recordings and document uploads (stored securely)",
          "App preferences (theme, colors, fonts)",
        ],
      },
      {
        subtitle: "Technical Information",
        text: "We automatically collect:",
        list: [
          "Device type and operating system version",
          "App version and crash reports",
          "IP address and general location (for security)",
        ],
      },
    ],
  },
  {
    icon: Shield,
    title: "How We Use Your Information",
    content: [
      {
        text: "We use your information to:",
        list: [
          "Provide and improve the coaching experience",
          "Generate AI responses from coaches",
          "Sync your data across devices",
          "Process subscription payments (via RevenueCat and Apple)",
          "Send important service notifications",
          "Prevent fraud and ensure security",
          "Comply with legal obligations",
        ],
      },
      {
        text: "We do NOT use your information to:",
        list: [
          "Show you advertisements",
          "Sell or rent your data to third parties",
          "Train AI models for other purposes",
          "Track you across other apps or websites",
        ],
      },
    ],
  },
  {
    icon: Lock,
    title: "How We Protect Your Information",
    content: [
      {
        text: "We implement industry-standard security measures:",
        list: [
          "TLS 1.3 encryption for all network traffic",
          "Firebase Authentication with secure token management",
          "Encrypted storage in Google Cloud Firestore",
          "Regular security audits and updates",
          "Access controls and monitoring",
        ],
      },
      {
        text: "While we strive to protect your information, no method of transmission over the internet is 100% secure. We cannot guarantee absolute security.",
      },
    ],
  },
  {
    icon: FileText,
    title: "Data Sharing and Third Parties",
    content: [
      {
        subtitle: "Service Providers",
        text: "We share data with trusted service providers who help us operate the app:",
        list: [
          "Google Cloud Platform (hosting and database)",
          "Firebase (authentication and storage)",
          "Vertex AI (AI model processing)",
          "ElevenLabs (text-to-speech)",
          "RevenueCat (subscription management)",
        ],
      },
      {
        text: "These providers are contractually obligated to protect your data and use it only for providing services to us.",
      },
      {
        subtitle: "Legal Requirements",
        text: "We may disclose your information if required by law, court order, or government request, or to protect our rights and safety.",
      },
    ],
  },
  {
    icon: UserCheck,
    title: "Your Rights and Choices",
    content: [
      {
        text: "You have the following rights:",
        list: [
          "Access: View all data we have about you",
          "Export: Download your data in a portable format",
          "Delete: Request deletion of your account and data",
          "Correct: Update inaccurate information",
          "Opt-out: Disable optional features like voice-over",
        ],
      },
      {
        text: "To exercise these rights, go to Settings → Privacy in the app or email privacy@simonaicoach.com.",
      },
    ],
  },
  {
    icon: Database,
    title: "Data Retention",
    content: [
      {
        text: "We retain your data as follows:",
        list: [
          "Account data: Until you delete your account",
          "Conversations: Until you delete them or your account",
          "Voice recordings: 30 days after upload (unless saved)",
          "Crash reports: 90 days",
          "Deleted data: Permanently removed within 30 days",
        ],
      },
    ],
  },
  {
    icon: Shield,
    title: "Children's Privacy",
    content: [
      {
        text: "Simon AI Coach is not intended for children under 13. We do not knowingly collect information from children under 13. If you believe we have collected information from a child under 13, please contact us immediately.",
      },
    ],
  },
  {
    icon: FileText,
    title: "International Data Transfers",
    content: [
      {
        text: "Your data may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place, including:",
        list: [
          "Standard contractual clauses",
          "Compliance with GDPR and CCPA",
          "Data processing agreements with service providers",
        ],
      },
    ],
  },
  {
    icon: Lock,
    title: "Changes to This Policy",
    content: [
      {
        text: "We may update this Privacy Policy from time to time. We will notify you of significant changes via:",
        list: [
          "In-app notification",
          "Email to your registered address",
          "Update to the 'Last updated' date at the top",
        ],
      },
      {
        text: "Your continued use of the app after changes constitutes acceptance of the updated policy.",
      },
    ],
  },
];
