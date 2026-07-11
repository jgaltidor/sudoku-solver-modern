import '@testing-library/jest-dom/vitest';

// React 18 checks this before letting act() suppress its "not wrapped in
// act" warnings -- without it, every act() call here still warns.
globalThis.IS_REACT_ACT_ENVIRONMENT = true;
