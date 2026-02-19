"use client";

import { motion } from "framer-motion";
import { Sparkles, MessageCircle, Zap, Brain, Calendar, Shield } from "lucide-react";
import Link from "next/link";

export default function Home() {
  return (
    <div className="relative overflow-hidden">
      {/* Hero Section */}
      <section className="relative pt-32 pb-20 px-6">
        <div className="max-w-6xl mx-auto">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="text-center"
          >
            <motion.div
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{ delay: 0.2, type: "spring" }}
              className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-primary-100 dark:bg-primary-900/30 text-primary-700 dark:text-primary-300 mb-6"
            >
              <Sparkles className="w-4 h-4" />
              <span className="text-sm font-medium">Minimalist AI Coaching</span>
            </motion.div>

            <h1 className="text-5xl md:text-7xl font-bold mb-6 text-balance">
              Build Systems
              <br />
              <span className="bg-gradient-to-r from-primary-600 to-purple-600 bg-clip-text text-transparent">
                That Stick
              </span>
            </h1>

            <p className="text-xl md:text-2xl text-gray-600 dark:text-gray-400 mb-8 max-w-3xl mx-auto text-balance">
              Personalized AI coaching in your pocket. Browse curated coaches, create custom ones, and get actionable guidance 24/7.
            </p>

            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.4 }}
              className="flex flex-col sm:flex-row gap-4 justify-center items-center"
            >
              <a
                href="#download"
                className="px-8 py-4 bg-primary-600 hover:bg-primary-700 text-white rounded-full font-semibold transition-all transform hover:scale-105 shadow-lg hover:shadow-xl"
              >
                Download for iOS
              </a>
              <a
                href="#features"
                className="px-8 py-4 bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-900 dark:text-gray-100 rounded-full font-semibold transition-all"
              >
                Learn More
              </a>
            </motion.div>
          </motion.div>

          {/* Floating Elements */}
          <div className="absolute top-20 left-10 w-20 h-20 bg-primary-200 dark:bg-primary-900/30 rounded-full blur-3xl animate-float" />
          <div className="absolute bottom-20 right-10 w-32 h-32 bg-purple-200 dark:bg-purple-900/30 rounded-full blur-3xl animate-float" style={{ animationDelay: "1s" }} />
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="py-20 px-6 bg-gray-50 dark:bg-gray-900/50">
        <div className="max-w-6xl mx-auto">
          <motion.div
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            className="text-center mb-16"
          >
            <h2 className="text-4xl md:text-5xl font-bold mb-4">
              Everything You Need
            </h2>
            <p className="text-xl text-gray-600 dark:text-gray-400">
              Powerful features wrapped in a minimalist design
            </p>
          </motion.div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            {features.map((feature, index) => (
              <motion.div
                key={feature.title}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: index * 0.1 }}
                className="p-6 bg-white dark:bg-gray-800 rounded-2xl shadow-lg hover:shadow-xl transition-all"
              >
                <div className="w-12 h-12 bg-primary-100 dark:bg-primary-900/30 rounded-xl flex items-center justify-center mb-4">
                  <feature.icon className="w-6 h-6 text-primary-600 dark:text-primary-400" />
                </div>
                <h3 className="text-xl font-semibold mb-2">{feature.title}</h3>
                <p className="text-gray-600 dark:text-gray-400">{feature.description}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 px-6">
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true }}
          className="max-w-4xl mx-auto text-center bg-gradient-to-br from-primary-600 to-purple-600 rounded-3xl p-12 shadow-2xl"
        >
          <h2 className="text-4xl md:text-5xl font-bold text-white mb-6">
            Ready to Build Better Systems?
          </h2>
          <p className="text-xl text-primary-100 mb-8">
            Start with 3 free messages. Upgrade anytime for unlimited access.
          </p>
          <a
            href="#download"
            className="inline-block px-8 py-4 bg-white text-primary-600 rounded-full font-semibold hover:bg-gray-100 transition-all transform hover:scale-105 shadow-lg"
          >
            Download Now
          </a>
        </motion.div>
      </section>
    </div>
  );
}

const features = [
  {
    icon: Brain,
    title: "AI Coach Library",
    description: "Browse curated coaches for focus, planning, creativity, and more. Create custom coaches tailored to your needs.",
  },
  {
    icon: MessageCircle,
    title: "Multi-Modal Chat",
    description: "Text, voice, or documents. Get streaming responses with optional voice-over using natural speech.",
  },
  {
    icon: Zap,
    title: "Quick Actions",
    description: "Pre-built templates for common needs. Ask anything and get routed to the best coach instantly.",
  },
  {
    icon: Calendar,
    title: "Intelligent Tools",
    description: "Coaches create plans, schedule events, set reminders, and remember your preferences.",
  },
  {
    icon: Sparkles,
    title: "Deep Personalization",
    description: "Choose themes, colors, fonts, and text sizes. All preferences sync across devices.",
  },
  {
    icon: Shield,
    title: "Privacy First",
    description: "Your data is encrypted and secure. No tracking, no ads, just coaching.",
  },
];
