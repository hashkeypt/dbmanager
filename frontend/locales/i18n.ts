import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import HttpBackend from 'i18next-http-backend';
import LanguageDetector from 'i18next-browser-languagedetector';

// Define all available namespaces
export const namespaces = [
  'common',
  'auth',
  'dashboard',
  'users',
  'permissions',
  'requests',
  'settings',
  'servers',
  'databases',
  'sync',
  'syncconfig',
  'sync-dashboard',
  'monitoring',
  'logs',
  'notifications',
  'profile',
  'access',
  'activation',
  'audit',
  'elasticsearch',
  'metrics',
  'reports',
  'validation'
] as const;

// Type for namespace
export type Namespace = typeof namespaces[number];

// Initialize i18n
i18n
  .use(HttpBackend)
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    fallbackLng: 'en',
    debug: process.env.NODE_ENV === 'development',
    
    // Namespace configuration
    ns: namespaces,
    defaultNS: 'common',
    
    // Improved performance settings
    react: {
      useSuspense: true,
      bindI18n: 'languageChanged loaded',
      bindI18nStore: 'added removed',
      transEmptyNodeValue: '',
      transSupportBasicHtmlNodes: true,
      transKeepBasicHtmlNodesFor: ['br', 'strong', 'i', 'p']
    },
    
    // Backend configuration
    backend: {
      loadPath: '/locales/{{lng}}/{{ns}}.json',
      crossDomain: false,
      withCredentials: false,
      requestOptions: {
        cache: 'no-cache'
      }
    },
    
    // Language detection options
    detection: {
      order: ['localStorage', 'navigator'],
      caches: ['localStorage'],
      excludeCacheFor: ['cimode'],
      checkWhitelist: true
    },
    
    // Interpolation options
    interpolation: {
      escapeValue: false
    },
    
    // Performance optimization
    load: 'languageOnly',
    preload: ['en', 'pt', 'es'],
    
    // Enable namespace loading
    partialBundledLanguages: true,
    cleanCode: true,
    
    // Resource loading
    saveMissing: process.env.NODE_ENV === 'development',
    saveMissingTo: 'current',
    missingKeyHandler: (lngs, ns, key) => {
      if (process.env.NODE_ENV === 'development') {
        console.warn(`Missing translation: ${ns}:${key}`);
      }
    }
  });

// Utility function to change language with localStorage persistence
export const changeLanguage = async (language: string) => {
  await i18n.changeLanguage(language);
  localStorage.setItem('i18nextLng', language);
};

// Export typed useTranslation hook
import { useTranslation as useTranslationBase } from 'react-i18next';

export const useTranslation = (ns?: Namespace | Namespace[]) => {
  return useTranslationBase(ns);
};

export default i18n;
