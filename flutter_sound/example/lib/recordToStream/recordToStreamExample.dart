/*
 * Copyright 2018, 2019, 2020 Dooboolab.
 *
 * This file is part of Flutter-Sound.
 *
 * Flutter-Sound is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License version 3 (LGPL-V3), as published by
 * the Free Software Foundation.
 *
 * Flutter-Sound is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Flutter-Sound.  If not, see <https://www.gnu.org/licenses/>.
 */


import 'package:flutter/material.dart';
import 'package:flauto/flutter_sound.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data' show Uint8List;

/*
 * This is an example showing how to record to a Dart Stream.
 * It writes all the recorded data from a Stream to a File, which is completely stupid:
 * if an App wants to record something to a File, it must not use Streams.
 *
 * The real interest of recording to a Stream is for example to feed a
 * Speech-to-Text engine, or for processing the Live data in Dart in real time.
 *
 */


const int SAMPLE_RATE = 8000;
typedef fn();


/// Example app.
class RecordToStreamExample extends StatefulWidget {
  @override
  _RecordToStreamExampleState createState() => _RecordToStreamExampleState();
}

class _RecordToStreamExampleState extends State<RecordToStreamExample> {

  FlutterSoundPlayer _mPlayer = FlutterSoundPlayer();
  FlutterSoundRecorder _mRecorder = FlutterSoundRecorder();
  bool _mPlayerIsInited = false;
  bool _mRecorderIsInited = false;
  bool _mplaybackReady = false;
  String _mPath;
  StreamSubscription  _mRecordingDataSubscription;


  @override
  void initState() {
    super.initState();
    // Be careful : openAudioSession return a Future.
    // Do not access your FlutterSoundPlayer or FlutterSoundRecorder before the completion of the Future
    _mPlayer.openAudioSession().then((value){  setState( (){_mPlayerIsInited = true;} );} );
    _mRecorder.openAudioSession().then((value){  setState( (){_mRecorderIsInited = true;} );} );
  }


  @override
  void dispose() {
      stopPlayer();
      _mPlayer.closeAudioSession();
      _mPlayer = null;

      stopRecorder();
      _mRecorder.closeAudioSession();
      _mRecorder = null;
    super.dispose();
  }

  Future<IOSink>  createFile() async
  {
    Directory tempDir = await getTemporaryDirectory();
    _mPath =
        '${tempDir.path}/flutter_sound_example.pcm';
    File outputFile = File(_mPath);
    if (outputFile.existsSync())
      await outputFile.delete();
    return outputFile.openWrite();
  }



  // ----------------------  Here is the code to record to a Stream ------------

  Future<void> record() async
  {
    assert (_mRecorderIsInited &&  _mPlayer.isStopped);
    IOSink sink = await createFile();
    StreamController<Food> recordingDataController = StreamController<Food>();
    _mRecordingDataSubscription =
          recordingDataController.stream.listen
            ((Food buffer)
              {
                if (buffer is FoodData)
                  sink.add(buffer.data);
                }
            );
    await _mRecorder.startRecorder(
        toStream: recordingDataController.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: SAMPLE_RATE,
    );
    setState(() {});
  }
  // --------------------- (it was very simple, wasn't it ?) -------------------




  Future<void> stopRecorder() async
  {
    await _mRecorder.stopRecorder();
    if (_mRecordingDataSubscription != null)
    {
      await _mRecordingDataSubscription.cancel();
      _mRecordingDataSubscription = null;
    }
    _mplaybackReady = true;
  }

  fn getRecorderFn()
  {
    if (!_mRecorderIsInited  || !_mPlayer.isStopped)
      return null;
    return _mRecorder.isStopped ? record : (){stopRecorder().then((value) => setState((){}));};

  }

  void play() async
  {
    assert (_mPlayerIsInited && _mplaybackReady && _mRecorder.isStopped && _mPlayer.isStopped);
    await _mPlayer.startPlayer(fromURI: _mPath, sampleRate: SAMPLE_RATE, codec: Codec.pcm16, numChannels: 1,whenFinished: (){setState((){});}); // The readability of Dart is very special :-(
    setState(() {});
  }

  Future<void> stopPlayer() async
  {
    await _mPlayer.stopPlayer();
  }

  fn getPlaybackFn()
  {
    if (!_mPlayerIsInited || !_mplaybackReady || !_mRecorder.isStopped)
      return null;
    return _mPlayer.isStopped ? play : (){stopPlayer().then((value) => setState((){}));};
  }

  // ----------------------------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    Widget makeBody()
    {
      return Column( children:[
        Container
          (
          margin: const EdgeInsets.all( 3 ),
          padding: const EdgeInsets.all( 3 ),
          height: 80,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration
            (
            color:  Color( 0xFFFAF0E6 ),
            border: Border.all( color: Colors.indigo, width: 3, ),
          ),
          child: Row(
              children: [
                RaisedButton(onPressed:  getRecorderFn(), color: Colors.white, disabledColor: Colors.grey, child: Text(_mRecorder.isRecording ? 'Stop' : 'Record'), ),
                SizedBox(width: 20,),
                Text(_mRecorder.isRecording ? 'Recording in progress' : 'Recorder is stopped'),
              ]
          ),
        ),

        Container
          (
          margin: const EdgeInsets.all( 3 ),
          padding: const EdgeInsets.all( 3 ),
          height: 80,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration
          (
            color:  Color( 0xFFFAF0E6 ),
            border: Border.all( color: Colors.indigo, width: 3, ),
          ),
          child: Row(
              children: [
                RaisedButton(onPressed: getPlaybackFn(), color: Colors.white, disabledColor: Colors.grey, child: Text(_mPlayer.isPlaying ? 'Stop' : 'Play'), ),
                SizedBox(width: 20,),
                Text(_mPlayer.isPlaying ? 'Playback in progress' : 'Player is stopped'),
              ]
          ),
        ),

      ],
      );
    }


    return Scaffold(backgroundColor: Colors.blue,
      appBar: AppBar(
        title: const Text('Record to Stream ex.'),
      ),
      body: makeBody(),
    );
  }
}
