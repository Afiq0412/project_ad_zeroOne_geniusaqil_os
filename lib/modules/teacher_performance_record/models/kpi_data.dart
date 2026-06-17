import 'package:flutter/material.dart';
import 'performance_model.dart';



class KpiData {
  static List<KpiCategory> buildCategories() {
    return [
      KpiCategory(
        id: 'attendance',
        title: 'Attendance & Punctuality',
        icon: Icons.access_time,
        criteria: [
          KpiCriterion(id: 'att_1', title: 'Arrives at school on time'),
          KpiCriterion(id: 'att_2', title: 'Comes prepared before class starts'),
          KpiCriterion(id: 'att_3', title: 'Follows attendance procedures'),
          KpiCriterion(id: 'att_4', title: 'Submits leave application properly'),
          KpiCriterion(id: 'att_5', title: 'Has good attendance record'),
        ],
      ),
      KpiCategory(
        id: 'classroom',
        title: 'Classroom Management',
        icon: Icons.class_,
        criteria: [
          KpiCriterion(id: 'cls_1', title: 'Classroom is clean and organised'),
          KpiCriterion(id: 'cls_2', title: 'Students are well managed'),
          KpiCriterion(id: 'cls_3', title: 'Learning corners are updated'),
          KpiCriterion(id: 'cls_4', title: 'Safety rules are followed'),
          KpiCriterion(id: 'cls_5', title: 'Students line up properly'),
        ],
      ),
      KpiCategory(
        id: 'teaching',
        title: 'Teaching Performance',
        icon: Icons.school,
        criteria: [
          KpiCriterion(id: 'tch_1', title: 'Lesson plan prepared on time'),
          KpiCriterion(id: 'tch_2', title: 'Lesson plan submitted on time'),
          KpiCriterion(id: 'tch_3', title: 'Teaching follows lesson plan (Sandbox)'),
          KpiCriterion(id: 'tch_4', title: 'Uses teaching aid effectively'),
          KpiCriterion(id: 'tch_5', title: 'Explains lesson clearly'),
          KpiCriterion(id: 'tch_6', title: 'Students are engaged during class'),
        ],
      ),
      KpiCategory(
        id: 'student_dev',
        title: 'Student Development',
        icon: Icons.child_care,
        criteria: [
          KpiCriterion(id: 'std_1', title: 'Tracks student progress'),
          KpiCriterion(id: 'std_2', title: 'Helps weak students'),
          KpiCriterion(id: 'std_3', title: 'Encourages student participation'),
          KpiCriterion(id: 'std_4', title: 'Maintains student discipline positively'),
          KpiCriterion(id: 'std_5', title: 'Gives motivation and encouragement'),
        ],
      ),
      KpiCategory(
        id: 'documentation',
        title: 'Documentation & Record Keeping',
        icon: Icons.folder,
        criteria: [
          KpiCriterion(id: 'doc_1', title: 'Students file updated'),
          KpiCriterion(id: 'doc_2', title: 'Attendance records complete'),
          KpiCriterion(id: 'doc_3', title: 'Assessment record submitted on time'),
          KpiCriterion(id: 'doc_4', title: 'Portfolio/student\'s work organised'),
        ],
      ),
      KpiCategory(
        id: 'communication',
        title: 'Communication & Professionalism',
        icon: Icons.people,
        criteria: [
          KpiCriterion(id: 'com_1', title: 'Speaks politely to students, parents and colleagues'),
          KpiCriterion(id: 'com_2', title: 'Responds professionally in WhatsApp groups'),
          KpiCriterion(id: 'com_3', title: 'Works well with team members'),
          KpiCriterion(id: 'com_4', title: 'Accepts feedback positively'),
          KpiCriterion(id: 'com_5', title: 'Maintains professional appearance'),
        ],
      ),
      KpiCategory(
        id: 'duty',
        title: 'Task & Duty Responsibility',
        icon: Icons.assignment_turned_in,
        criteria: [
          KpiCriterion(id: 'dty_1', title: 'Follows assembly duty schedule'),
          KpiCriterion(id: 'dty_2', title: 'Follows cleaning duty schedule'),
          KpiCriterion(id: 'dty_3', title: 'Completes arrival and dismissal duty'),
          KpiCriterion(id: 'dty_4', title: 'Helps during school events'),
        ],
      ),
      KpiCategory(
        id: 'creativity',
        title: 'Creativity & Initiative',
        icon: Icons.lightbulb,
        criteria: [
          KpiCriterion(id: 'crt_1', title: 'Creates attractive teaching materials'),
          KpiCriterion(id: 'crt_2', title: 'Gives new activity ideas'),
          KpiCriterion(id: 'crt_3', title: 'Participates in school improvement'),
          KpiCriterion(id: 'crt_4', title: 'Decorates classroom creatively'),
          KpiCriterion(id: 'crt_5', title: 'Takes initiative without waiting for instruction'),
        ],
      ),
      KpiCategory(
        id: 'training',
        title: 'Training & Self Development',
        icon: Icons.auto_stories,
        criteria: [
          KpiCriterion(id: 'trn_1', title: 'Attends required training (minimum 3 per year)'),
          KpiCriterion(id: 'trn_2', title: 'Applies knowledge from training'),
          KpiCriterion(id: 'trn_3', title: 'Shares learning with team'),
          KpiCriterion(id: 'trn_4', title: 'Improves teaching skills'),
        ],
      ),
      KpiCategory(
        id: 'discipline',
        title: 'Discipline & SOP Compliance',
        icon: Icons.verified_user,
        criteria: [
          KpiCriterion(id: 'dis_1', title: 'Follows school SOP'),
          KpiCriterion(id: 'dis_2', title: 'Uses appropriate language'),
          KpiCriterion(id: 'dis_3', title: 'Follows dress code'),
          KpiCriterion(id: 'dis_4', title: 'Maintains confidentiality'),
          KpiCriterion(id: 'dis_5', title: 'Uses social media professionally'),
        ],
      ),
    ];
  }
}