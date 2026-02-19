"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { motion } from "framer-motion";
import { Moon, Sun, Menu, X } from "lucide-react";

export function Navigation() {
  const [isOpen, setIsOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [mounted, setMounted] = useState(false);
  const [currentTheme, setCurrentTheme] = useState<"light" | "dark">("light");
  const pathname = usePathname();

  useEffect(() => {
    setMounted(true);
    // Get initial theme
    const stored = localStorage.getItem("theme");
    if (stored === "dark" || stored === "light") {
      setCurrentTheme(stored);
    } else {
      const systemTheme = window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
      setCurrentTheme(systemTheme);
    }
  }, []);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  const toggleTheme = () => {
    const newTheme = currentTheme === "dark" ? "light" : "dark";
    setCurrentTheme(newTheme);
    localStorage.setItem("theme", newTheme);
    
    const root = window.document.documentElement;
    root.classList.remove("light", "dark");
    root.classList.add(newTheme);
  };

  return (
    <nav
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled
          ? "bg-white/80 dark:bg-gray-950/80 backdrop-blur-lg shadow-lg"
          : "bg-transparent"
      }`}
    >
      <div className="max-w-7xl mx-auto px-6 py-4">
        <div className="flex items-center justify-between">
          {/* Logo */}
          <Link href="/" className="flex items-center gap-2 group">
            <div className="w-10 h-10 bg-gradient-to-br from-primary-600 to-purple-600 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform">
              <span className="text-white font-bold text-xl">S</span>
            </div>
            <span className="text-xl font-bold">Simon AI Coach</span>
          </Link>

          {/* Desktop Navigation */}
          <div className="hidden md:flex items-center gap-8">
            <Link
              href="/"
              className={`hover:text-primary-600 dark:hover:text-primary-400 transition-colors ${
                pathname === "/" ? "text-primary-600 dark:text-primary-400" : ""
              }`}
            >
              Home
            </Link>
            <Link
              href="/support"
              className={`hover:text-primary-600 dark:hover:text-primary-400 transition-colors ${
                pathname === "/support" ? "text-primary-600 dark:text-primary-400" : ""
              }`}
            >
              Support
            </Link>
            <Link
              href="/privacy"
              className={`hover:text-primary-600 dark:hover:text-primary-400 transition-colors ${
                pathname === "/privacy" ? "text-primary-600 dark:text-primary-400" : ""
              }`}
            >
              Privacy
            </Link>
            {mounted && (
              <button
                onClick={toggleTheme}
                className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
                aria-label="Toggle theme"
              >
                {currentTheme === "dark" ? (
                  <Sun className="w-5 h-5" />
                ) : (
                  <Moon className="w-5 h-5" />
                )}
              </button>
            )}
          </div>

          {/* Mobile Menu Button */}
          <button
            onClick={() => setIsOpen(!isOpen)}
            className="md:hidden p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
            aria-label="Toggle menu"
          >
            {isOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
          </button>
        </div>

        {/* Mobile Navigation */}
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="md:hidden mt-4 pb-4 space-y-4"
          >
            <Link
              href="/"
              onClick={() => setIsOpen(false)}
              className={`block py-2 hover:text-primary-600 dark:hover:text-primary-400 transition-colors ${
                pathname === "/" ? "text-primary-600 dark:text-primary-400" : ""
              }`}
            >
              Home
            </Link>
            <Link
              href="/support"
              onClick={() => setIsOpen(false)}
              className={`block py-2 hover:text-primary-600 dark:hover:text-primary-400 transition-colors ${
                pathname === "/support" ? "text-primary-600 dark:text-primary-400" : ""
              }`}
            >
              Support
            </Link>
            <Link
              href="/privacy"
              onClick={() => setIsOpen(false)}
              className={`block py-2 hover:text-primary-600 dark:hover:text-primary-400 transition-colors ${
                pathname === "/privacy" ? "text-primary-600 dark:text-primary-400" : ""
              }`}
            >
              Privacy
            </Link>
            {mounted && (
              <button
                onClick={toggleTheme}
                className="flex items-center gap-2 py-2 hover:text-primary-600 dark:hover:text-primary-400 transition-colors"
              >
                {currentTheme === "dark" ? (
                  <>
                    <Sun className="w-5 h-5" />
                    <span>Light Mode</span>
                  </>
                ) : (
                  <>
                    <Moon className="w-5 h-5" />
                    <span>Dark Mode</span>
                  </>
                )}
              </button>
            )}
          </motion.div>
        )}
      </div>
    </nav>
  );
}
