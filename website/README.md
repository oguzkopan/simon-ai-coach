# Simon AI Coach Website

A beautiful, modern website for the Simon AI Coach mobile app, built with Next.js 14, TypeScript, Tailwind CSS, and Framer Motion.

## Features

- 🎨 Beautiful, minimalist design with smooth animations
- 🌓 Dark/Light theme support with system preference detection
- 📱 Fully responsive for all devices
- ⚡ Fast and optimized with Next.js 14 App Router
- 🎭 Smooth animations with Framer Motion
- 📄 Static pages for Support and Privacy (required for App Store)
- 🎯 SEO optimized with proper metadata

## Pages

- **Home** (`/`) - Landing page with features and CTA
- **Support** (`/support`) - FAQ, contact info, and getting started guide
- **Privacy** (`/privacy`) - Comprehensive privacy policy
- **Terms** (`/terms`) - Terms of service

## Getting Started

### Prerequisites

- Node.js 18+ and npm/yarn/pnpm

### Installation

```bash
cd website
npm install
```

### Development

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### Build for Production

```bash
npm run build
npm start
```

### Static Export

The site is configured for static export (perfect for hosting on Netlify, Vercel, GitHub Pages, etc.):

```bash
npm run build
```

The static files will be in the `out` directory.

## Deployment

### Vercel (Recommended)

1. Push to GitHub
2. Import project in Vercel
3. Deploy automatically

### Netlify

1. Push to GitHub
2. Connect repository in Netlify
3. Build command: `npm run build`
4. Publish directory: `out`

### GitHub Pages

1. Build: `npm run build`
2. Push `out` directory to `gh-pages` branch

## Customization

### Colors

Edit `tailwind.config.ts` to change the color palette:

```typescript
colors: {
  primary: {
    // Your custom colors
  },
}
```

### Content

- Update page content in `app/*/page.tsx`
- Modify navigation in `components/Navigation.tsx`
- Edit footer in `components/Footer.tsx`

### Animations

Animations are powered by Framer Motion. Customize in each page component.

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Animations**: Framer Motion
- **Icons**: Lucide React
- **Fonts**: Inter (Google Fonts)

## App Store Requirements

This website includes the required static pages for App Store Connect:

- **Support URL**: `https://yourdomain.com/support`
- **Privacy Policy URL**: `https://yourdomain.com/privacy`

Make sure to update these URLs in App Store Connect after deployment.

## License

MIT License - See LICENSE file for details

## Contact

For questions or support, email: support@simonaicoach.com
