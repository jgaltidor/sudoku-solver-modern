import {
  beforeAll,
  beforeEach,
  afterEach,
  describe,
  it,
  expect,
  vi,
} from 'vitest';
import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { act } from 'react';

// index.jsx mounts itself into #root as an import-time side effect (no
// exported component to render directly) -- so tests drive the single
// mounted instance through its own UI (Solve/Clear buttons, cell inputs)
// rather than rendering a fresh tree per test.
function getCellInputs() {
  return document.querySelectorAll('input.inputcell');
}

describe('Sudoku Solver app', () => {
  let user;

  beforeAll(async () => {
    document.body.innerHTML = '<div id="root"></div>';
    // createRoot(...).render(...) schedules React 18's render rather than
    // flushing it synchronously -- act() forces it to flush before the
    // first test's assertions run, the same way RTL's own render() helper
    // does internally (index.jsx calls createRoot directly, not that helper).
    await act(async () => {
      await import('./index.jsx');
    });
  });

  beforeEach(async () => {
    user = userEvent.setup();
    global.fetch = vi.fn();
    // Reset any board state left over from the previous test via the app's
    // own Clear button, rather than remounting the whole tree.
    await user.click(screen.getByText('Clear'));
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('renders the 9x9 grid and the initial prompt', () => {
    expect(screen.getByText('Sudoku Solver')).toBeInTheDocument();
    expect(
      screen.getByText('Enter numbers [1-9] in the grid'),
    ).toBeInTheDocument();
    expect(getCellInputs()).toHaveLength(81);
  });

  it('solves a board and fills in the computed values', async () => {
    const solvedBoard = [
      [5, 3, 4, 6, 7, 8, 9, 1, 2],
      [6, 7, 2, 1, 9, 5, 3, 4, 8],
      [1, 9, 8, 3, 4, 2, 5, 6, 7],
      [8, 5, 9, 7, 6, 1, 4, 2, 3],
      [4, 2, 6, 8, 5, 3, 7, 9, 1],
      [7, 1, 3, 9, 2, 4, 8, 5, 6],
      [9, 6, 1, 5, 3, 7, 2, 8, 4],
      [2, 8, 7, 4, 1, 9, 6, 3, 5],
      [3, 4, 5, 2, 8, 6, 1, 7, 9],
    ];
    global.fetch.mockResolvedValue({
      ok: true,
      json: async () => ({ has_solution: true, solved_board: solvedBoard }),
    });

    await user.click(screen.getByText('Solve'));

    await waitFor(() =>
      expect(screen.getByText('Solution Found!')).toBeInTheDocument(),
    );
    expect(getCellInputs()[0].value).toBe('5');
    expect(getCellInputs()[80].value).toBe('9');
    expect(global.fetch).toHaveBeenCalledWith(
      '/solve',
      expect.objectContaining({ method: 'post' }),
    );
  });

  it('shows a message when no solution exists', async () => {
    global.fetch.mockResolvedValue({
      ok: true,
      json: async () => ({ has_solution: false }),
    });

    await user.click(screen.getByText('Solve'));

    await waitFor(() =>
      expect(screen.getByText('No Solution Exists!')).toBeInTheDocument(),
    );
  });

  it('lets the user type a value into a cell', async () => {
    const input = getCellInputs()[0];
    await user.type(input, '7');
    expect(input.value).toBe('7');
  });

  it('clears the board back to the initial state', async () => {
    const input = getCellInputs()[0];
    await user.type(input, '7');
    expect(input.value).toBe('7');

    await user.click(screen.getByText('Clear'));

    expect(
      screen.getByText('Enter numbers [1-9] in the grid'),
    ).toBeInTheDocument();
    expect(getCellInputs()[0].value).toBe('');
  });
});
