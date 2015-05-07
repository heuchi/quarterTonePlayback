//==============================================
//  play back quarter tone accidentals
//
//  Copyright (C)2012-2014 Jörn Eichler (heuchi) 
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//==============================================

import QtQuick 2.0
import MuseScore 1.0

MuseScore {
      version: "0.1"
      description: "This plugin adds playback for quarter tone accidentals"
      menuPath: "Plugins.Notes.Quarter Tone Playback"

      // accidental configuration
      property var accConfig;

      // if nothing is selected process whole score
      property bool processAll: false

      // function iniConfig

      function iniConfig() {
            accConfig = [];
            // standard accidentals that are handled by MuseScore
            accConfig[Accidental.FLAT2]   = 0;
            accConfig[Accidental.FLAT]    = 0;
            accConfig[Accidental.NATURAL] = 0;
            accConfig[Accidental.SHARP]   = 0;
            accConfig[Accidental.SHARP2]  = 0;

            // standard configuration for quarter tone accidentals
            accConfig[Accidental.MIRRORED_FLAT] = -50;
            accConfig[Accidental.SHARP_SLASH]   =  50;
      }

      // function tpcName
      //
      // return name of note

      function tpcName(tpc) {
            var tpcNames = new Array(
                  "Fbb", "Cbb", "Gbb", "Dbb", "Abb", "Ebb", "Bbb",
                  "Fb",   "Cb",   "Gb",   "Db",   "Ab",   "Eb",   "Bb",
                  "F",     "C",     "G",     "D",     "A",     "E",     "B",
                  "F#",   "C#",   "G#",   "D#",   "A#",    "E#",   "B#",
                  "F##", "C##", "G##", "D##", "A##",  "E##",  "B##"
             );

            return(tpcNames[tpc+1]);
      }

      // function getEndStaffOfPart
      //
      // return the first staff that does not belong to
      // the part containing given start staff.

      function getEndStaffOfPart(startStaff) {
            var startTrack = startStaff * 4;
            var parts = curScore.parts;

            for(var i = 0; i < parts.length; i++) {
                  var part = parts[i];

                  if( (part.startTrack <= startTrack)
                        && (part.endTrack > startTrack) ) {
                        return(part.endTrack/4);
                  }
            }

            // not found!
            console.log("error: part for " + startStaff + " not found!");
            Qt.quit();
      }

      // function processNote
      //
      // for each measure we create a table that contains 
      // the current tuning of each 'noteClass'
      //
      // a 'noteClass' is the natural name of a space
      // or line of the staff and the octave:
      // C5, F6, B3 are 'noteClass'
      //   
      // curTuningArray[<noteClass>] = <tuning>

      function processNote(note,curTuningArray) {
            var octave=Math.floor(note.pitch/12);

            // use tpc1 instead of tpc for octave correction
            // since this will also work for transposing instruments
            // correct octave for Cb and Cbb
            if(note.tpc1 == 7 || note.tpc1 == 0) {
                  octave++; // belongs to higher octave
            }
            // correct octave for B# and B##
            if(note.tpc1 == 26 || note.tpc1 == 33) {
                  octave--; // belongs to lower octave
            }

            var noteClass = tpcName(note.tpc).charAt(0)+octave;

            console.log("found note "+noteClass);

	    // reset tuning
	    var tuning = 0;

	    // has there been an accidental for this note in this measure?
	    if (typeof curTuningArray[noteClass] !== 'undefined') {
	       tuning = curTuningArray[noteClass];
	    }

	    // has this note an accidental we need to consider?
	    if (note.accidental && 
	      (typeof accConfig[note.accidentalType] !== 'undefined')) {
	      tuning = accConfig[note.accidentalType];
	      // remember for rest of measure
	      curTuningArray[noteClass] = tuning;
	    }

	    // set note.tuning if it differs from what we calculated
	    if (note.tuning != tuning) {
	       note.tuning = tuning;
	    }
            console.log("tuning for "+noteClass+" calculated to"+tuning);
      }

      // function processPart
      //
      // do the actual work: process all given tracks in parallel
      // set tuning where needed.
      //
      // We go through all tracks simultaneously, because we also want 
      // to consider accidentals in other voices of the same part

      function processPart(cursor,endTick,startTrack,endTrack) {
            if(processAll) {
                  // we need to reset track first, otherwise
                  // rewind(0) doesn't work correctly
                  cursor.track=0; 
                  cursor.rewind(0);
            } else {
                  cursor.rewind(1);
            }

            var segment = cursor.segment;

            // we use the cursor to know measure boundaries
            cursor.nextMeasure();

            var curTuningArray = [];

            // we use a segment, because the cursor always proceeds to 
            // the next element in the given track and we don't know 
            // in which track the element is.
            var inLastMeasure=false;
            while(segment && (processAll || segment.tick < endTick)) {
                  // check if still inside same measure
                  if(!inLastMeasure && !(segment.tick < cursor.tick)) {
                        // new measure
                        curTuningArray = [];
                        if(!cursor.nextMeasure()) {
                              inLastMeasure=true;
                        }
                  }

                  for(var track=startTrack; track<endTrack; track++) {
                        // look for notes and grace notes
                        if(segment.elementAt(track) && segment.elementAt(track).type == Element.CHORD) {
                              // process graceNotes if present
                              if(segment.elementAt(track).graceNotes.length > 0) {
                                    var graceChords = segment.elementAt(track).graceNotes;
                                    
                                    for(var j=0;j<graceChords.length;j++) {
                                          var notes = graceChords[j].notes;
                                          for(var i=0;i<notes.length;i++) {
                                                processNote(notes[i],curTuningArray);
                                          }
                                    }
                              }

                              // process notes
                              var notes = segment.elementAt(track).notes;
                              
                              for(var i=0;i<notes.length;i++) {
                                    processNote(notes[i],curTuningArray);
                              }
                        }
                  }
                  segment=segment.next;
            }
      }

      function quarterToneTuning() {
             if (typeof curScore === 'undefined' || curScore == null) {
                   console.log("error: no score!");	     
                   Qt.quit();
             }

            // find selection
            var startStaff;
            var endStaff;
            var endTick;
            
            var cursor = curScore.newCursor();
            cursor.rewind(1);
            if(!cursor.segment) {
                  // no selection
                  processAll = true;
                  startStaff = 0;
                  endStaff = curScore.nstaves;
            } else {
                  startStaff = cursor.staffIdx;
                  cursor.rewind(2);
                  endStaff = cursor.staffIdx+1;
                  endTick = cursor.tick;
                  if(endTick == 0) {
                        // selection includes end of score
                        // calculate tick from last score segment
                        endTick = curScore.lastSegment.tick + 1;
                  }
                  cursor.rewind(1);
            }      

            // go through all staves of a part simultaneously
            // find staves that belong to the same part

            var curStartStaff = startStaff;

            while(curStartStaff < endStaff) {
                  // find end staff for this part
                  var curEndStaff = getEndStaffOfPart(curStartStaff);

                  if(curEndStaff > endStaff) {
                        curEndStaff = endStaff;
                  }

                  // do the work
                  processPart(cursor,endTick,curStartStaff*4,curEndStaff*4);

                  // next part
                  curStartStaff = curEndStaff;
            }

            Qt.quit();
      }

      onRun: { 
            iniConfig();
            quarterToneTuning();
      }
}
