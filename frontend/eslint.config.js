import js from '@eslint/js';
import react from 'eslint-plugin-react';
import reactHooks from 'eslint-plugin-react-hooks';
import globals from 'globals';
import prettierConfig from 'eslint-config-prettier';

export default [
  { ignores: ['dist/**', 'node_modules/**'] },
  js.configs.recommended,
  react.configs.flat.recommended,
  {
    plugins: { 'react-hooks': reactHooks },
    rules: reactHooks.configs.recommended.rules,
  },
  {
    languageOptions: {
      globals: { ...globals.browser },
    },
    settings: {
      react: { version: 'detect' },
    },
    rules: {
      // This codebase's UI is deliberately old-style React (class
      // components, no JSX transform import needed) -- see CLAUDE.md.
      'react/react-in-jsx-scope': 'off',
      'react/prop-types': 'off',
    },
  },
  {
    // Runs under Node at dev-server startup, not in the browser bundle
    // (see its own comment on why it reads process.env directly).
    files: ['vite.config.js'],
    languageOptions: {
      globals: { ...globals.node },
    },
  },
  prettierConfig,
];
