// The showcase's sample form and saved answers: the same JSON as the web showcase
// (form-builder.sample.ts) and the shared engine fixtures (test/form_engine/fixtures).
import 'dart:async';
import 'dart:convert';

import 'package:zouriel_ui/zouriel_ui.dart';

/// The scholarship application, as the web builder stores it.
final UiJson sampleForm = (jsonDecode(_form) as Map).cast<String, Object?>();

/// One saved set of answers to [sampleForm].
final UiJson sampleAnswers = (jsonDecode(_answers) as Map).cast<String, Object?>();

const _first = ['Aminath', 'Ibrahim', 'Mariyam', 'Ahmed', 'Fathimath', 'Mohamed', 'Aishath', 'Hassan', 'Hawwa', 'Ali', 'Khadheeja', 'Hussain', 'Zaha', 'Ismail', 'Shifa', 'Yoosuf', 'Nashwa', 'Adam', 'Raufa', 'Saeed'];
const _last = ['Shareef', 'Rasheed', 'Naseem', 'Waheed', 'Hameed', 'Latheef', 'Zahir', 'Manik', 'Didi', 'Fulhu', 'Moosa', 'Saleem', 'Habeeb', 'Riyaz', 'Shakir', 'Nizar', 'Faiz', 'Jaleel', 'Adnan', 'Shiham'];
const _faculties = {'stem': 'Science and engineering', 'arts': 'Arts and humanities', 'health': 'Health and medicine', 'vocational': 'Vocational training'};
const _courses = {
  'stem': ['Calculus I', 'Linear algebra', 'Programming fundamentals', 'Data structures', 'Physics for engineers', 'Marine biology', 'Renewable energy systems', 'Statistics', 'Chemistry I', 'Databases', 'Computer networks', 'Environmental science'],
  'arts': ['Dhivehi literature', 'World history', 'Creative writing', 'Philosophy of mind', 'Art history', 'Linguistics', 'Media studies', 'Music theory', 'Islamic studies', 'Translation practice'],
  'health': ['Anatomy', 'Physiology', 'Community health', 'Pharmacology', 'Nursing practice I', 'Nursing practice II', 'Public health nutrition', 'Medical ethics', 'Microbiology', 'First aid and emergency care', 'Mental health care'],
  'vocational': ['Hospitality operations', 'Diving instruction', 'Electrical installation', 'Boat building', 'Culinary arts', 'Tourism management', 'Plumbing', 'Air conditioning and refrigeration'],
};

final _students = [
  for (var i = 0; i < 600; i++)
    (
      faculty: _faculties.keys.elementAt((i * 7 + i ~/ 20) % 4),
      item: UiFbSourceItem(
        value: 'S${(240117 + i * 13).toString().padLeft(6, '0')}',
        label: '${_first[i % 20]} ${_last[(i * 3 + i ~/ 20) % 20]}',
        description: 'S${(240117 + i * 13).toString().padLeft(6, '0')} · ${_faculties[_faculties.keys.elementAt((i * 7 + i ~/ 20) % 4)]}',
      ),
    ),
];

/// Answers from memory after a short pause, so paging, searching, cancelling and the loading
/// states behave as they would over a network. A real app's `search` calls its API.
Future<UiFbSourcePage> _page(List<UiFbSourceItem> list, UiFbSourceQuery q) {
  final needle = q.query.toLowerCase();
  final hits = needle.isEmpty ? list : list.where((x) => x.label.toLowerCase().contains(needle) || '${x.value}'.toLowerCase().contains(needle)).toList();
  final items = hits.skip((q.page - 1) * q.pageSize).take(q.pageSize).toList();
  final done = Completer<UiFbSourcePage>();
  final timer = Timer(const Duration(milliseconds: 300), () => done.complete(UiFbSourcePage(items: items, total: hits.length)));
  q.signal.onAbort(() {
    timer.cancel();
    if (!done.isCompleted) done.completeError(StateError('aborted'));
  });
  return done.future;
}

/// "Students": 600 records, searched by name or ID, optionally one faculty.
final studentsSource = UiFbOptionSource(
  type: 'students',
  label: 'Students',
  description: 'Everyone in the student records (600 in this demo), searched by name or ID.',
  params: [UiFbSourceParamSpec(key: 'faculty', label: 'Faculty', kind: 'select', options: [for (final e in _faculties.entries) (value: e.key, label: e.value)])],
  pageSize: 20,
  search: (q) => _page([for (final s in _students) if (q.params['faculty'] == null || q.params['faculty'] == s.faculty) s.item], q),
);

/// "Courses": the courses of one programme (follows the Programme answer in the sample).
final coursesSource = UiFbOptionSource(
  type: 'courses',
  label: 'Courses',
  description: 'Courses offered by one programme.',
  params: [UiFbSourceParamSpec(key: 'programme', label: 'Programme', kind: 'select', required: true, options: [for (final e in _faculties.entries) (value: e.key, label: e.value)])],
  pageSize: 8,
  search: (q) {
    final p = '${q.params['programme'] ?? ''}';
    final names = _courses[p] ?? const <String>[];
    return _page([for (var i = 0; i < names.length; i++) UiFbSourceItem(value: '$p-${i + 1}', label: names[i])], q);
  },
);

final demoSources = <UiFbOptionSourceDef>[studentsSource, coursesSource];

const _form = r'''
{
  "schemaVersion": 1,
  "id": "scholarship-2027",
  "title": "Scholarship application",
  "description": "Takes about 10 minutes. Your answers are saved when you submit.",
  "revision": 4,
  "settings": {
    "labelPlacement": "top",
    "errorPlacement": "below",
    "validateOn": "blur",
    "clearHidden": "onSubmit",
    "errorSummary": true,
    "requiredMarker": "asterisk",
    "showProgress": true
  },
  "pages": [
    {
      "id": "p_about",
      "title": "About you",
      "elements": [
        {
          "kind": "field",
          "id": "f_name",
          "type": "text",
          "key": "full_name",
          "label": "Full name",
          "required": true,
          "props": {
            "autocomplete": "name"
          },
          "layout": {
            "width": "half"
          }
        },
        {
          "kind": "field",
          "id": "f_pref",
          "type": "text",
          "key": "preferred_name",
          "label": "Preferred name",
          "help": "What we should call you, if different.",
          "layout": {
            "width": "half"
          }
        },
        {
          "kind": "field",
          "id": "f_email",
          "type": "email",
          "key": "email",
          "label": "Email address",
          "required": true,
          "layout": {
            "width": "half"
          }
        },
        {
          "kind": "field",
          "id": "f_phone",
          "type": "phone",
          "key": "phone",
          "label": "Mobile number",
          "layout": {
            "width": "half"
          }
        },
        {
          "kind": "field",
          "id": "f_dob",
          "type": "date",
          "key": "date_of_birth",
          "label": "Date of birth",
          "required": true,
          "layout": {
            "width": "half"
          },
          "validators": [
            {
              "id": "v_age",
              "type": "ageAtLeast",
              "params": {
                "years": 16
              },
              "message": "Applicants must be 16 or older."
            }
          ]
        },
        {
          "kind": "field",
          "id": "f_age",
          "type": "calculated",
          "key": "age",
          "label": "Age",
          "calc": {
            "op": "ageYears",
            "args": [
              {
                "ref": "f_dob"
              }
            ]
          },
          "props": {
            "format": "number",
            "suffix": "years"
          },
          "layout": {
            "width": "half"
          }
        },
        {
          "kind": "field",
          "id": "f_status",
          "type": "radio",
          "key": "study_status",
          "label": "Are you studying at the moment?",
          "required": true,
          "props": {
            "orientation": "horizontal"
          },
          "options": [
            {
              "id": "o_s1",
              "value": "full_time",
              "label": "Full time"
            },
            {
              "id": "o_s2",
              "value": "part_time",
              "label": "Part time"
            },
            {
              "id": "o_s3",
              "value": "not_studying",
              "label": "Not studying"
            }
          ]
        },
        {
          "kind": "field",
          "id": "f_inst",
          "type": "text",
          "key": "institution",
          "label": "School or university",
          "required": true,
          "visibility": {
            "action": "hide",
            "when": {
              "ref": "f_status",
              "op": "eq",
              "value": {
                "const": "not_studying"
              }
            }
          }
        },
        {
          "kind": "field",
          "id": "f_record",
          "type": "select",
          "key": "student_record",
          "label": "Your student record",
          "help": "Search by name or student ID. Leave it blank if you’re not enrolled yet.",
          "source": {
            "type": "students"
          },
          "visibility": {
            "action": "hide",
            "when": {
              "ref": "f_status",
              "op": "eq",
              "value": {
                "const": "not_studying"
              }
            }
          }
        },
        {
          "kind": "field",
          "id": "f_dep",
          "type": "toggle",
          "key": "has_dependants",
          "label": "Do you support any dependants?",
          "props": {
            "caption": "Yes, I do"
          }
        }
      ]
    },
    {
      "id": "p_household",
      "title": "Household",
      "visibility": {
        "action": "show",
        "when": {
          "ref": "f_dep",
          "op": "isTrue"
        }
      },
      "elements": [
        {
          "kind": "group",
          "id": "g_deps",
          "key": "dependants",
          "title": "Dependants",
          "columns": 2,
          "repeat": {
            "min": 1,
            "max": 6,
            "addLabel": "Add a dependant",
            "itemLabel": "Dependant {n}"
          },
          "elements": [
            {
              "kind": "field",
              "id": "f_dep_name",
              "type": "text",
              "key": "name",
              "label": "Name",
              "required": true
            },
            {
              "kind": "field",
              "id": "f_dep_rel",
              "type": "select",
              "key": "relationship",
              "label": "Relationship",
              "required": true,
              "options": [
                {
                  "id": "o_r1",
                  "value": "child",
                  "label": "Child"
                },
                {
                  "id": "o_r2",
                  "value": "parent",
                  "label": "Parent"
                },
                {
                  "id": "o_r3",
                  "value": "sibling",
                  "label": "Sibling"
                },
                {
                  "id": "o_r4",
                  "value": "other",
                  "label": "Other"
                }
              ]
            },
            {
              "kind": "field",
              "id": "f_dep_other",
              "type": "text",
              "key": "relationship_other",
              "label": "How are you related?",
              "required": true,
              "visibility": {
                "action": "show",
                "when": {
                  "ref": "f_dep_rel",
                  "op": "eq",
                  "value": {
                    "const": "other"
                  }
                }
              },
              "layout": {
                "width": "full"
              }
            }
          ]
        },
        {
          "kind": "group",
          "id": "g_income",
          "key": "income",
          "title": "Monthly household income",
          "columns": 3,
          "elements": [
            {
              "kind": "field",
              "id": "f_wages",
              "type": "currency",
              "key": "wages",
              "label": "Wages",
              "props": {
                "currency": "USD",
                "decimals": 2,
                "min": 0
              }
            },
            {
              "kind": "field",
              "id": "f_benefits",
              "type": "currency",
              "key": "benefits",
              "label": "Benefits",
              "props": {
                "currency": "USD",
                "decimals": 2,
                "min": 0
              }
            },
            {
              "kind": "field",
              "id": "f_total",
              "type": "calculated",
              "key": "total",
              "label": "Total",
              "calc": {
                "op": "sum",
                "args": [
                  {
                    "ref": "f_wages"
                  },
                  {
                    "ref": "f_benefits"
                  }
                ],
                "decimals": 2
              },
              "props": {
                "format": "currency",
                "currency": "USD",
                "decimals": 2
              }
            }
          ]
        }
      ]
    },
    {
      "id": "p_application",
      "title": "Your application",
      "elements": [
        {
          "kind": "field",
          "id": "f_prog",
          "type": "select",
          "key": "programme",
          "label": "Programme",
          "required": true,
          "placeholder": "Choose a programme",
          "options": [
            {
              "id": "o_p1",
              "value": "stem",
              "label": "Science and engineering"
            },
            {
              "id": "o_p2",
              "value": "arts",
              "label": "Arts and humanities"
            },
            {
              "id": "o_p3",
              "value": "health",
              "label": "Health and medicine"
            },
            {
              "id": "o_p4",
              "value": "vocational",
              "label": "Vocational training"
            }
          ]
        },
        {
          "kind": "field",
          "id": "f_courses",
          "type": "multiselect",
          "key": "courses",
          "label": "Courses you’ll take",
          "help": "The list follows the programme you picked. Choose up to four.",
          "source": {
            "type": "courses",
            "params": {
              "programme": {
                "ref": "f_prog"
              }
            }
          },
          "validators": [
            {
              "id": "v_courses",
              "type": "maxSelected",
              "params": {
                "max": 4
              }
            }
          ]
        },
        {
          "kind": "field",
          "id": "f_statement",
          "type": "textarea",
          "key": "statement",
          "label": "Personal statement",
          "required": true,
          "help": "Tell us why you are applying and what you hope to achieve. 50 to 300 words.",
          "validators": [
            {
              "id": "v_min",
              "type": "minWords",
              "params": {
                "min": 50
              }
            },
            {
              "id": "v_max",
              "type": "maxWords",
              "params": {
                "max": 300
              }
            }
          ]
        },
        {
          "kind": "field",
          "id": "f_docs",
          "type": "file",
          "key": "documents",
          "label": "Supporting documents",
          "props": {
            "multiple": true,
            "accept": ".pdf,image/*"
          },
          "help": "Transcripts or letters of reference. PDF or images, up to 5 MB each.",
          "required": {
            "when": {
              "ref": "f_prog",
              "op": "eq",
              "value": {
                "const": "health"
              }
            }
          },
          "validators": [
            {
              "id": "v_size",
              "type": "maxFileSize",
              "params": {
                "mb": 5
              }
            }
          ]
        },
        {
          "kind": "field",
          "id": "f_consent",
          "type": "checkbox",
          "key": "consent",
          "label": "Declaration",
          "required": true,
          "requiredMessage": "You must confirm the declaration to apply.",
          "props": {
            "caption": "The information I have given is true and complete."
          }
        }
      ]
    }
  ]
}
''';

const _answers = r'''
{
  "full_name": "Aminath Shareef",
  "email": "aminath.shareef@example.mv",
  "phone": "+960 777 4021",
  "date_of_birth": "2004-03-19",
  "age": 22,
  "study_status": "part_time",
  "institution": "Maldives National University",
  "student_record": {
    "value": "S240117",
    "label": "Aminath Shareef"
  },
  "has_dependants": true,
  "dependants": [
    {
      "name": "Ibrahim",
      "relationship": "sibling"
    }
  ],
  "income": {
    "wages": 1240,
    "benefits": 180,
    "total": 1420
  },
  "programme": "health",
  "courses": [
    {
      "value": "health-1",
      "label": "Anatomy"
    },
    {
      "value": "health-5",
      "label": "Nursing practice I"
    }
  ],
  "statement": "I have worked part time at a community clinic in Hulhumalé for two years while studying, and I want to train as a nurse so I can do more for the patients I meet there. Many of them travel from the islands for care that should be closer to home. With this scholarship I would finish my degree without working nights, and then return to the clinic to help run its community health visits.",
  "documents": [
    {
      "name": "transcript-2026.pdf",
      "size": 184320,
      "type": "application/pdf"
    }
  ],
  "consent": true,
  "submitted_from": "kiosk-3"
}
''';
