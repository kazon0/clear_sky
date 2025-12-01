import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_view_model.dart';
import 'login_page.dart';
import '../widgets/dialog.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _idController = TextEditingController();
  final _pwdController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _pwdObscure = true;
  bool _confirmObscure = true;

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    return Scaffold(
      body: AnimatedBuilder(
        animation: authVM,
        builder: (context, _) {
          return Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/bg_register.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              Positioned(
                top: 50,
                left: 16,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  color: Color.fromARGB(255, 63, 83, 101),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),

              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // --- 注册表单 ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Column(
                          children: [
                            TextField(
                              controller: _idController,
                              decoration: InputDecoration(
                                labelText: '学号',
                                hintText: '请输入9位数字',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                ),
                                prefixIcon: const Icon(
                                  Icons.perm_identity,
                                  color: Color(0xFF6F99BF),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: _pwdController,
                              obscureText: _pwdObscure,
                              decoration: InputDecoration(
                                labelText: '密码',
                                hintText: '至少 8 位，包含字母和数字',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFF6F99BF),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _pwdObscure
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _pwdObscure = !_pwdObscure;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),
                            TextField(
                              controller: _confirmController,
                              obscureText: _confirmObscure,
                              decoration: InputDecoration(
                                labelText: '确认密码',
                                hintText: '请再次输入密码',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_person_outlined,
                                  color: Color(0xFF6F99BF),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _confirmObscure
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _confirmObscure = !_confirmObscure;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // --- 注册按钮 ---
                      authVM.isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: 300,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (_pwdController.text !=
                                      _confirmController.text) {
                                    showPrettyAlertDialog(
                                      context,
                                      title: "密码不一致",
                                      message: "请确认两次输入的密码相同哦～",
                                    );
                                    return;
                                  }
                                  final ok = await authVM.register(
                                    _idController.text.trim(),
                                    _pwdController.text.trim(),
                                  );

                                  // 注册失败提示
                                  if (!ok) {
                                    showPrettyAlertDialog(
                                      context,
                                      title: "注册失败",
                                      message: authVM.message ?? "请稍后再试试～",
                                    );
                                    return;
                                  }

                                  // 注册成功提示
                                  if (ok && mounted) {
                                    showPrettyAlertDialog(
                                      context,
                                      title: "注册成功",
                                      message: "欢迎加入晴空心理～现在可以登录啦！",
                                      onConfirm: () => Navigator.pop(context),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    121,
                                    166,
                                    207,
                                  ),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 3,
                                ),
                                child: const Text(
                                  '注册',
                                  style: TextStyle(
                                    fontSize: 18,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),

                      // const SizedBox(height: 20),

                      // if (authVM.message != null)
                      //   Text(
                      //     authVM.message!,
                      //     style: TextStyle(
                      //       color: authVM.message == '注册成功'
                      //           ? Colors.green
                      //           : Colors.red,
                      //     ),
                      //   ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '已有账号？',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                              );
                            },
                            child: const Text(
                              '去登录',
                              style: TextStyle(
                                color: Color.fromARGB(255, 121, 162, 200),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
