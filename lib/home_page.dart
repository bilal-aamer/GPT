import 'package:chat_gpt_flutter/chat_gpt_flutter.dart';
import 'package:chatgpt_audio_text/chat_message.model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:text_to_speech/text_to_speech.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return const ChatPage();
  }
}

const backgroundColor = Color(0xff343541);
const botBackgroundColor = Color(0xff444654);

// You have to create OpenAI account and request API key from here: https://beta.openai.com/account/api-keys
const API_KEY = "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";

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  late ChatGpt chatGpt;

  SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';

  late TextToSpeech tts;

  late bool isLoading;

  @override
  void initState() {
    super.initState();
    chatGpt = ChatGpt(apiKey: API_KEY);
    _initSpeech();
    tts = TextToSpeech();
    isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'GPT Home - Chat',
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
        ),
        backgroundColor: botBackgroundColor,
      ),
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildList(),
            ),
            Visibility(
              visible: isLoading,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  _buildInput(),
                  _buildSubmit(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmit() {
    return Visibility(
      visible: !isLoading,
      child: Container(
        color: botBackgroundColor,
        child: IconButton(
          icon: const Icon(
            Icons.send_rounded,
            color: Color.fromRGBO(142, 142, 160, 1),
          ),
          onPressed: () async {
            var input = _textController.text;
            _textController.clear();
            _localSend(input);
          },
        ),
      ),
    );
  }

  _localSend(String input) async {
    setState(
      () {
        _messages.add(
          ChatMessage(
            text: input,
            chatMessageType: ChatMessageType.user,
          ),
        );
        isLoading = true;
      },
    );
    Future.delayed(const Duration(milliseconds: 50)).then((_) => _scrollDown());
    _sendMessage(input);
  }

  _sendMessage(String input) async {
    final testRequest = CompletionRequest(
      prompt: input,
      model: ChatGptModel.textDavinci003.key,
      maxTokens: 1000,
      temperature: 1,
    );

    final result = await chatGpt.createCompletion(testRequest);

    setState(() {
      isLoading = false;
      _messages.add(
        ChatMessage(
          text: result ?? "",
          chatMessageType: ChatMessageType.bot,
        ),
      );
      try {
        tts.speak(result ?? "");
      } catch (err) {
        print(err);
      }
    });
    _textController.clear();
    Future.delayed(const Duration(milliseconds: 50)).then((_) => _scrollDown());
  }

  _copyMessage(String message) {
    Clipboard.setData(ClipboardData(text: message)).then((_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Message copied to clipboard")));
    });
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (error) {
        setState(() {});
        print(error);
      },
      onStatus: (status) => print(status),
    );
    setState(() {});
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  /// Manually stop the active speech recognition session
  /// Note that there are also timeouts that each platform enforces
  /// and the SpeechToText plugin supports setting timeouts on the
  /// listen method.
  void _stopListening() async {
    await _speechToText.stop();
    if (_lastWords.isNotEmpty) {
      _textController.text = _lastWords;
      _localSend(_lastWords);
    }
    setState(() {});
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns recognized words.
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
      _textController.text = _lastWords;
    });
    if (result.finalResult) {
      _localSend(_lastWords);
    }
  }

  Expanded _buildInput() {
    return Expanded(
      child: TextField(
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(color: Colors.white),
        controller: _textController,
        decoration: InputDecoration(
          fillColor: botBackgroundColor,
          filled: true,
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          suffixIcon: _speechEnabled
              ? IconButton(
                  icon: Icon(
                    _speechToText.isNotListening
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    color: const Color.fromRGBO(142, 142, 160, 1),
                  ),
                  onPressed: _speechToText.isNotListening
                      ? _startListening
                      : _stopListening,
                )
              : null,
        ),
      ),
    );
  }

  ListView _buildList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        var message = _messages[index];
        return ChatMessageWidget(
          text: message.text,
          chatMessageType: message.chatMessageType,
          onCopy: () {
            _copyMessage(message.text);
          },
        );
      },
    );
  }

  void _scrollDown() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}

class ChatMessageWidget extends StatelessWidget {
  const ChatMessageWidget({
    super.key,
    required this.text,
    required this.chatMessageType,
    this.onCopy,
  });

  final String text;
  final ChatMessageType chatMessageType;
  final Function? onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      color: chatMessageType == ChatMessageType.bot
          ? botBackgroundColor
          : backgroundColor,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              chatMessageType == ChatMessageType.bot
                  ? Container(
                      margin: const EdgeInsets.only(right: 16.0),
                      child: CircleAvatar(
                        backgroundColor: const Color.fromRGBO(16, 163, 127, 1),
                        child: Image.asset(
                          'assets/bot.png',
                          color: Colors.white,
                          scale: 1.5,
                        ),
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.only(right: 16.0),
                      child: const CircleAvatar(
                        child: Icon(
                          Icons.person,
                        ),
                      ),
                    ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
                      ),
                      child: Text(
                        text,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.copy),
              iconSize: 16,
              color: const Color.fromRGBO(142, 142, 160, 1),
              onPressed: () {
                onCopy?.call();
              },
            ),
          ),
        ],
      ),
    );
  }
}
