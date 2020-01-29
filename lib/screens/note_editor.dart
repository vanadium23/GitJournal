import 'package:flutter/material.dart';
import 'package:fimber/fimber.dart';

import 'package:gitjournal/core/note.dart';
import 'package:gitjournal/core/notes_folder.dart';
import 'package:gitjournal/editors/markdown_editor.dart';
import 'package:gitjournal/editors/raw_editor.dart';
import 'package:gitjournal/state_container.dart';
import 'package:gitjournal/core/note_data_serializers.dart';
import 'package:gitjournal/utils.dart';
import 'package:gitjournal/widgets/folder_selection_dialog.dart';
import 'package:gitjournal/widgets/rename_dialog.dart';

class NoteEditor extends StatefulWidget {
  final Note note;
  final NotesFolder notesFolder;

  NoteEditor.fromNote(this.note) : notesFolder = null;
  NoteEditor.newNote(this.notesFolder) : note = null;

  @override
  NoteEditorState createState() {
    if (note == null) {
      return NoteEditorState.newNote(notesFolder);
    } else {
      return NoteEditorState.fromNote(note);
    }
  }
}

enum EditorType { Markdown, Raw }

class NoteEditorState extends State<NoteEditor> {
  Note note;
  EditorType editorType = EditorType.Markdown;
  String noteSerialized = "";

  final _rawEditorKey = GlobalKey<RawEditorState>();
  final _markdownEditorKey = GlobalKey<MarkdownEditorState>();

  bool get _isNewNote {
    return widget.note == null;
  }

  NoteEditorState.newNote(NotesFolder folder) {
    note = Note.newNote(folder);
  }

  NoteEditorState.fromNote(this.note) {
    var serializer = MarkdownYAMLSerializer();
    noteSerialized = serializer.encode(note.data);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _saveNote(_getNoteFromEditor());
        return true;
      },
      child: _getEditor(),
    );
  }

  Widget _getEditor() {
    switch (editorType) {
      case EditorType.Markdown:
        return MarkdownEditor(
          key: _markdownEditorKey,
          note: note,
          noteDeletionSelected: _noteDeletionSelected,
          noteEditorChooserSelected: _noteEditorChooserSelected,
          exitEditorSelected: _exitEditorSelected,
          renameNoteSelected: _renameNoteSelected,
          moveNoteToFolderSelected: _moveNoteToFolderSelected,
          autofocusOnEditor: _isNewNote,
        );
      case EditorType.Raw:
        return RawEditor(
          key: _rawEditorKey,
          note: note,
          noteDeletionSelected: _noteDeletionSelected,
          noteEditorChooserSelected: _noteEditorChooserSelected,
          exitEditorSelected: _exitEditorSelected,
          renameNoteSelected: _renameNoteSelected,
          moveNoteToFolderSelected: _moveNoteToFolderSelected,
        );
    }
    return null;
  }

  void _noteEditorChooserSelected(Note _note) async {
    var newEditorType = await showDialog<EditorType>(
      context: context,
      builder: (BuildContext context) {
        var children = <Widget>[
          RadioListTile<EditorType>(
            title: const Text("Markdown Editor"),
            value: EditorType.Markdown,
            groupValue: editorType,
            onChanged: (EditorType et) => Navigator.of(context).pop(et),
          ),
          RadioListTile<EditorType>(
            title: const Text("Raw Editor"),
            value: EditorType.Raw,
            groupValue: editorType,
            onChanged: (EditorType et) => Navigator.of(context).pop(et),
          ),
        ];

        return AlertDialog(
          title: const Text("Choose Editor"),
          content: Column(
            children: children,
            mainAxisSize: MainAxisSize.min,
          ),
        );
      },
    );

    if (newEditorType != null) {
      setState(() {
        note = _note;
        editorType = newEditorType;
      });
    }
  }

  void _exitEditorSelected(Note note) {
    _saveNote(note);
    Navigator.pop(context);
  }

  void _renameNoteSelected(Note _note) async {
    var fileName = await showDialog(
      context: context,
      builder: (_) => RenameDialog(
        oldPath: note.filePath,
        inputDecoration: 'File Name',
        dialogTitle: "Rename File",
      ),
    );
    if (fileName is String) {
      if (_isNewNote) {
        setState(() {
          note = _note;
          note.rename(fileName);
        });
      }
      final container = StateContainer.of(context);
      container.renameNote(note, fileName);
    }
  }

  void _noteDeletionSelected(Note note) {
    if (_isNewNote && !_noteModified(note)) {
      Navigator.pop(context);
      return;
    }

    showDialog(context: context, builder: _buildAlertDialog);
  }

  void _deleteNote(Note note) {
    if (_isNewNote) {
      return;
    }

    final stateContainer = StateContainer.of(context);
    stateContainer.removeNote(note);
  }

  Widget _buildAlertDialog(BuildContext context) {
    var title = "Do you want to delete this note?";
    var editText = "Keep Writing";
    var discardText = "Discard";

    return AlertDialog(
      title: Text(title),
      actions: <Widget>[
        FlatButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(editText),
        ),
        FlatButton(
          onPressed: () {
            _deleteNote(note);

            Navigator.pop(context); // Alert box
            Navigator.pop(context); // Note Editor

            if (!_isNewNote) {
              Fimber.d("Showing an undo snackbar");

              final stateContainer = StateContainer.of(context);
              showUndoDeleteSnackbar(context, stateContainer, note);
            }
          },
          child: Text(discardText),
        ),
      ],
    );
  }

  bool _noteModified(Note note) {
    if (_isNewNote) {
      return note.title.isNotEmpty || note.body.isNotEmpty;
    }
    var serializer = MarkdownYAMLSerializer();
    var finalNoteSerialized = serializer.encode(note.data);
    return finalNoteSerialized != noteSerialized;
  }

  void _saveNote(Note note) {
    if (!_noteModified(note)) return;

    print("Note modified - saving");
    final stateContainer = StateContainer.of(context);
    _isNewNote ? stateContainer.addNote(note) : stateContainer.updateNote(note);
  }

  Note _getNoteFromEditor() {
    switch (editorType) {
      case EditorType.Markdown:
        return _markdownEditorKey.currentState.getNote();
      case EditorType.Raw:
        return _rawEditorKey.currentState.getNote();
    }
    return null;
  }

  void _moveNoteToFolderSelected(Note note) async {
    var destFolder = await showDialog<NotesFolder>(
      context: context,
      builder: (context) => FolderSelectionDialog(),
    );
    if (destFolder != null) {
      final stateContainer = StateContainer.of(context);
      stateContainer.moveNote(note, destFolder);
    }
  }
}