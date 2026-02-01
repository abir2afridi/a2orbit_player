import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Developer Info',
                style: GoogleFonts.raleway(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white24,
                        child: Icon(
                          Icons.person,
                          size: 55,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Abir Hasan Siam',
                        style: GoogleFonts.raleway(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Flutter & Full-stack Developer',
                        style: GoogleFonts.raleway(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildSection('User Profile Summary', [
                _buildInfoRow('Name', 'Abir Hasan Siam'),
                _buildInfoRow('Date of Birth', '17 November 2002'),
                _buildInfoRow('Age', '22'),
                _buildInfoRow('Location', 'Gazipur, Dhaka, Bangladesh'),
                _buildInfoRow('Origin', 'Tangail'),
                _buildInfoRow('Blood Group', 'B+'),
              ]),
              _buildSection('Education', [
                _buildEducationTile(
                  'Independent University of Bangladesh',
                  'BSc in Computer Science',
                  '2021 - Present',
                ),
                _buildEducationTile(
                  'Misir Ali Khan Memorial School & College',
                  'HSC',
                  '2019 - 2020',
                ),
                _buildEducationTile(
                  'Professor MEH Arif Secondary School',
                  'SSC',
                  '2017 - 2018',
                ),
              ]),
              _buildSection('Skills & Interests', [
                _buildSkillsList([
                  'Programming: Dart (Flutter), React, Python',
                  'Mobile App Development: Android APK, Flutter',
                  'Web Development: React.js, HTML, CSS, JavaScript',
                  'OS & Tools: Windows, Linux, Terminal, CMake, VM',
                  'Design & UI: App UI/UX, Gradient & Card-based layouts',
                  'Version Control: Git, GitHub',
                ]),
              ]),
              _buildSection('Personal Traits', [
                _buildSkillsList([
                  'Detail-oriented and curious',
                  'Enjoys experimenting with cross-platform solutions',
                  'Likes to keep projects clean, optimized, and professional',
                ]),
              ]),
              _buildSection('Notable Practices', [
                _buildSkillsList([
                  'Maintains clean Flutter project structure',
                  'Prefers step-by-step technical clarity',
                  'Strong focus on first-time app launch experience',
                  'Considers multi-OS compatibility in development',
                ]),
              ]),
              _buildSection('Contact & Online Presence', [
                _buildContactTile(
                  Icons.link,
                  'GitHub',
                  'github.com/abir2afridi',
                ),
                _buildContactTile(
                  Icons.web,
                  'Portfolio',
                  'abir2afridi.vercel.app',
                ),
                _buildContactTile(
                  Icons.email,
                  'Email',
                  'abir2afridi@gmail.com',
                ),
              ]),
              const SizedBox(height: 40),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.raleway(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2575FC),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationTile(String school, String degree, String year) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            school,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            '$degree · $year',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsList(List<String> skills) {
    return Column(
      children: skills
          .map(
            (skill) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      skill,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildContactTile(IconData icon, String label, String value) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.blueAccent, size: 20),
        ),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 13, color: Colors.blueAccent),
        ),
        dense: true,
        onTap: () {},
      ),
    );
  }
}
