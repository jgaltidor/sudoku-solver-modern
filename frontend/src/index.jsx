import React from 'react';
import { createRoot } from 'react-dom/client';
import './index.css';

function ColumnLabel(props) {
  return (
    <div className = "gridCell gridLabel gridColumnLabel border" >{props.label}</div>
  );
}

function SquareColumnSeparator() {
  return (
    <div className = "gridColumnSeparator" />
  );
}

function RowLabel(props) {
  return (
    <div className = "gridCell gridLabel gridRowLabel border" >{props.label}</div>
  );
}

function RowSeparator() {
  return (
    <div style={{clear: 'both'}} />
  );
}

function TitleRow() {
  return (
    <div className = "gridRow" >
      <ColumnLabel label="" />
      <ColumnLabel label="1" />
      <ColumnLabel label="2" />
      <ColumnLabel label="3" />
      <SquareColumnSeparator />
      <ColumnLabel label="4" />
      <ColumnLabel label="5" />
      <ColumnLabel label="6" />
      <SquareColumnSeparator />
      <ColumnLabel label="7" />
      <ColumnLabel label="8" />
      <ColumnLabel label="9" />
    </div>
  );
}

class Cell extends React.Component
{
  constructor(props) {
    super(props);
    this.state = {
      row        : props.coordinate.row,
      col        : props.coordinate.col,
      game       : props.coordinate.game
    };
    this.handleChange = this.handleChange.bind(this);
  }

  handleChange(event) {
    let newValue = event.target.value;
    let row = this.state.row;
    let col = this.state.col;
    this.state.game.updateCell(row, col, newValue);
  }

  isComputed() {
    let row = this.state.row;
    let col = this.state.col;
    return this.state.game.isCellComputed(row, col);
  }

  render() {
    let styleClasses = "gridCell inputcell";
    if(this.isComputed()) {
      styleClasses = styleClasses + " computedcell";
    }
    return (
      <input className  = {styleClasses}
             type       = "text"
             maxLength  = "1"
             value      = {this.getValue()}
             onChange   = {this.handleChange}>
      </input>
    );
  }

  getValue() {
    const row  = this.state.row;
    const col  = this.state.col;
    const game = this.state.game;
    return game.getCellValue(row, col);
  }
}

function ColumnSeparator() {
  return (
    <div className = "gridColumnSeparator"></div>
  );
}


class GridRow extends React.Component
{
  constructor(props) {
    super(props);
    this.state = {
      rowlabel  : props.rowlabel,
      row       : props.row,
    }
  }

  render() {
    return (
      <div className = "gridRow" >
        <RowLabel label  = {this.state.rowlabel} />
        <Cell coordinate = {this.state.row[0]} />
        <Cell coordinate = {this.state.row[1]} />
        <Cell coordinate = {this.state.row[2]} />
        <ColumnSeparator />
        <Cell coordinate = {this.state.row[3]} />
        <Cell coordinate = {this.state.row[4]} />
        <Cell coordinate = {this.state.row[5]} />
        <ColumnSeparator />
        <Cell coordinate = {this.state.row[6]} />
        <Cell coordinate = {this.state.row[7]} />
        <Cell coordinate = {this.state.row[8]} />
      </div>
    );
  }
}

function SquareRowSeparator() {
  return (
    <div>
      <RowSeparator />
      <div className = "gridRowSeparator" />
      <RowSeparator />
    </div>
  );
}

class Grid extends React.Component
{
  constructor(props) {
    super(props);
    this.state = {
      coordinates: props.coordinates
    };
  }

  render() {
    return (
      <div className="grid">
        <TitleRow />
        <RowSeparator />
        <GridRow rowlabel="A" row={this.state.coordinates[0]} />
        <GridRow rowlabel="B" row={this.state.coordinates[1]} />
        <GridRow rowlabel="C" row={this.state.coordinates[2]} />
        <SquareRowSeparator />
        <GridRow rowlabel="D" row={this.state.coordinates[3]} />
        <GridRow rowlabel="E" row={this.state.coordinates[4]} />
        <GridRow rowlabel="F" row={this.state.coordinates[5]} />
        <SquareRowSeparator />
        <GridRow rowlabel="G" row={this.state.coordinates[6]} />
        <GridRow rowlabel="H" row={this.state.coordinates[7]} />
        <GridRow rowlabel="I" row={this.state.coordinates[8]} />
      </div>
    );
  }
}

class MessageArea extends React.Component
{
  constructor(props) {
    super(props);
    this.state = {
      game : props.game
    };
  }

  getMessage() {
    return this.state.game.getMessage();
  }

  render() {
    return (
      <div className="button rounded message-box"
        >{this.getMessage()}</div>
    );
  }
}

class Game extends React.Component
{
  constructor(props) {
    super(props);
    const coordinates = this.createCellCoordinates();
    const values = this.createClearCellValues();
    const message = this.getInitialMessage();
    const isComputedFlags = this.getInitialIsComputedFlags();
    this.state = {
      coordinates      : coordinates,
      values           : values,
      isComputedFlags  : isComputedFlags,
      message          : message
    };
  }

  createClearCellValues() {
    const values = new Array(9);
    for(let i = 0; i < values.length; i++) {
      values[i] = new Array(9);
      for(let j = 0; j < values[i].length; j++) {
        values[i][j] = '';
      }
    }
    return values;
  }

  createCellCoordinates() {
    const coordinates = new Array(9);
    for(let i = 0; i < coordinates.length; i++) {
      coordinates[i] = new Array(9);
      for(let j = 0; j < coordinates[i].length; j++) {
        coordinates[i][j] = this.createCellCoordinate(i, j);
      }
    }
    return coordinates;
  }

  createCellCoordinate(row, col) {
    return {
      row        : row,
      col        : col,
      game       : this
    };
  }

  getInitialMessage() {
    return 'Enter numbers [1-9] in the grid';
  }

  getInitialIsComputedFlags() {
    const flags = new Array(9);
    for(let i = 0; i < flags.length; i++) {
      flags[i] = new Array(9);
      for(let j = 0; j < flags[i].length; j++) {
        flags[i][j] = false;
      }
    }
    return flags;
  }

  cloneValues() {
    const values = new Array(this.state.values.length);
    for(let i = 0; i < values.length; i++) {
      values[i] = new Array(this.state.values[i].length);
      for(let j = 0; j < values[i].length; j++) {
        values[i][j] = this.getCellValue(i, j);
      }
    }
    return values;
  }

  updateCell(row, col, value) {
    const values = this.cloneValues();
    values[row][col] = value;
    const isComputedFlags = this.getInitialIsComputedFlags();
    this.setState({
      values             : values,
      isComputedFlags    : isComputedFlags,
      coordinates        : this.state.coordinates,
      message            : this.state.message
    });
  }

  getCellValue(row, col) {
    return this.state.values[row][col];
  }

  isCellComputed(row, col) {
    return this.state.isComputedFlags[row][col];
  }

  handleSolveClick() {
    this.updateMessage("Solving...");
    let inputBoardJSON = this.jsonOfBoard();
    let inputBoardStr = JSON.stringify(inputBoardJSON);
    fetch(
      '/api/sudoku',
      {
        method  : 'post',
        headers : { 'Content-Type': 'text/plain' },
        body: inputBoardStr
      }
    )
    .then((response) => {
      if(response.ok) {
        return response.json();
      } else {
        throw new Error(response.statusText);
      }
    })
    .then((responseJson) => {
      this.processSolverResponse(responseJson);
    })
    .catch((error) => {
      console.error(error);
    });
  }

  updateMessage(newMessage) {
    this.setState({
      message         : newMessage,
      values          : this.state.values,
      isComputedFlags : this.state.isComputedFlags,
      coordinates     : this.state.coordinates,
    });
  }

  handleClearClick() {
    const values    = this.createClearCellValues();
    const isComputedFlags = this.getInitialIsComputedFlags();
    const message  = this.getInitialMessage();
    const coordinates = this.createCellCoordinates();
    this.setState({
      values          : values,
      isComputedFlags : isComputedFlags,
      message         : message,
      coordinates     : coordinates
    });
  }

  getCellNumber(row, col) {
    let value = this.getCellValue(row, col);
    let num = parseInt(value, 10);
    if(num >= 1 && num <= 9) return num;
    else return 0;
  }

  jsonOfBoard() {
    let rows = new Array(this.state.values.length);;
    for(let i = 0; i < rows.length; i++) {
      rows[i] = new Array(this.state.values[i].length);
      for(let j = 0; j < rows[i].length; j++) {
        rows[i][j] = this.getCellNumber(i, j);
      }
    }
    return {'board': rows};
  }

  valuesOfNums(board_of_nums) {
    let values = new Array(board_of_nums.length);;
    for(let i = 0; i < values.length; i++) {
      values[i] = new Array(board_of_nums[i].length);
      for(let j = 0; j < values[i].length; j++) {
        values[i][j] = board_of_nums[i][j].toString();
      }
    }
    return values;
  }

  getNewIsComputedFlags(newValues) {
    const flags = new Array(9);
    for(let i = 0; i < flags.length; i++) {
      flags[i] = new Array(9);
      for(let j = 0; j < flags[i].length; j++) {
        let isComputed = null;
        let newValue = newValues[i][j];
        let oldValue = this.getCellValue(i, j);
        if(newValue === oldValue) isComputed = false;
        else isComputed = true;
        flags[i][j] = isComputed;
      }
    }
    return flags;
  }

  processSolverResponse(responseJson) {
    let message = null;
    let values = this.state.values;
    let isComputedFlags = this.state.isComputedFlags;
    if(responseJson.has_solution) {
      let solution = responseJson.solved_board;
      message = 'Solution Found!';
      values = this.valuesOfNums(solution);
      isComputedFlags = this.getNewIsComputedFlags(values);
    }
    else {
      message = 'No Solution Exists!'
    }
    this.setState({
      values             : values,
      isComputedFlags    : isComputedFlags,
      message            : message,
      coordinates        : this.state.coordinates
    });
  }

  getMessage() {
    return this.state.message;
  }

  render() {
    return (
      <div className="root-box blue-box">
        <div className="pageHeaderTitle">Sudoku Solver</div>
        <div style={{clear: 'both'}}></div>
        <div className="mainContent">
          <div className="left-box">
            <Grid coordinates={this.state.coordinates} />
          </div>
          <div className="right-box">
            <ButtonArea
              solveClick = {() => this.handleSolveClick()}
              clearClick = {() => this.handleClearClick()}
            />
            <div style={{clear: 'both', height: '20px'}}></div>
            <MessageArea game = {this} />
          </div>
        </div>
      </div>
    );
  }
}

class ButtonArea extends React.Component
{
  constructor(props) {
    super(props);
    this.state = {
      solveClick : props.solveClick,
      clearClick : props.clearClick
    }
  }

  render() {
    return (
      <div className="buttonsContainer">
        <fieldset id="buttonArea">
          <legend id="buttonAreaLegend">Features</legend>
          <button
            className = "button rounded"
            onClick   = {() => this.state.solveClick()}
            >Solve</button>
          <div style ={{clear: 'both', height: '20px'}}></div>
          <button
            className = "button rounded"
            onClick   = {() => this.state.clearClick()}
            >Clear</button>
        </fieldset>
      </div>
    );
  }
}

createRoot(document.getElementById('root')).render(<Game />);
