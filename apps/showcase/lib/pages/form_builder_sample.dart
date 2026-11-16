// The showcase's sample form and saved answers: the same JSON as the web showcase
// (form-builder.sample.ts, English and Dhivehi) and the shared engine fixtures (test/form_engine/fixtures).
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
  "schemaVersion": 2,
  "defaultLocale": "en",
  "supportedLocales": [
    {
      "code": "en",
      "label": "English",
      "dir": "ltr"
    },
    {
      "code": "dv",
      "label": "ދިވެހި",
      "dir": "rtl"
    }
  ],
  "id": "scholarship-2027",
  "title": {
    "en": "Scholarship application",
    "dv": "ސްކޮލަރޝިޕަށް އެދޭ ފޯމު"
  },
  "description": {
    "en": "Takes about 10 minutes. Your answers are saved when you submit.",
    "dv": "މިއަށް ގާތްގަނޑަކަށް 10 މިނިޓު ނަގައެވެ. ފޯމު ހުށަހަޅުއްވުމުން ތިޔަބޭފުޅާގެ ޖަވާބުތައް ރައްކާކުރެވޭނެއެވެ."
  },
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
      "title": {
        "en": "About you",
        "dv": "ތިޔަބޭފުޅާއަށް ބެހޭ"
      },
      "elements": [
        {
          "kind": "field",
          "id": "f_name",
          "type": "text",
          "key": "full_name",
          "label": {
            "en": "Full name",
            "dv": "ފުރިހަމަ ނަން"
          },
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
          "label": {
            "en": "Preferred name",
            "dv": "ގޮވާނެ ނަން"
          },
          "help": {
            "en": "What we should call you, if different.",
            "dv": "އެހެން ނަމެއްގައި ގޮވަންޖެހޭނަމަ، އެ ނަން."
          },
          "layout": {
            "width": "half"
          }
        },
        {
          "kind": "field",
          "id": "f_email",
          "type": "email",
          "key": "email",
          "label": {
            "en": "Email address",
            "dv": "އީމެއިލް އެޑްރެސް"
          },
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
          "label": {
            "en": "Mobile number",
            "dv": "މޯބައިލް ނަންބަރު"
          },
          "layout": {
            "width": "half"
          }
        },
        {
          "kind": "field",
          "id": "f_dob",
          "type": "date",
          "key": "date_of_birth",
          "label": {
            "en": "Date of birth",
            "dv": "އުފަން ތާރީޚު"
          },
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
              "message": {
                "en": "Applicants must be 16 or older.",
                "dv": "އެދޭ މީހުންގެ އުމުރު 16 އަހަރު ނުވަތަ އެއަށްވުރެ ބޮޑުވާންޖެހެއެވެ."
              }
            }
          ]
        },
        {
          "kind": "field",
          "id": "f_age",
          "type": "calculated",
          "key": "age",
          "label": {
            "en": "Age",
            "dv": "އުމުރު"
          },
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
          "label": {
            "en": "Are you studying at the moment?",
            "dv": "މިހާރު ކިޔަވަނީތަ؟"
          },
          "required": true,
          "props": {
            "orientation": "horizontal"
          },
          "options": [
            {
              "id": "o_s1",
              "value": "full_time",
              "label": {
                "en": "Full time",
                "dv": "ފުލް ޓައިމް"
              }
            },
            {
              "id": "o_s2",
              "value": "part_time",
              "label": {
                "en": "Part time",
                "dv": "ޕާޓް ޓައިމް"
              }
            },
            {
              "id": "o_s3",
              "value": "not_studying",
              "label": {
                "en": "Not studying",
                "dv": "ނުކިޔަވަމޭ"
              }
            }
          ]
        },
        {
          "kind": "field",
          "id": "f_inst",
          "type": "text",
          "key": "institution",
          "label": {
            "en": "School or university",
            "dv": "ސްކޫލް ނުވަތަ ޔުނިވަރސިޓީ"
          },
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
          "label": {
            "en": "Your student record",
            "dv": "ތިޔަބޭފުޅާގެ ދަރިވަރު ރެކޯޑު"
          },
          "help": {
            "en": "Search by name or student ID. Leave it blank if you’re not enrolled yet.",
            "dv": "ނަމުން ނުވަތަ ދަރިވަރުގެ އައިޑީން ހޯދާށެވެ. އަދި ނުކިޔަވާނަމަ ހުސްކޮށް ދޫކޮށްލައްވާ."
          },
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
          "label": {
            "en": "Do you support any dependants?",
            "dv": "ތިޔަބޭފުޅުންގެ ބެލުމުގެ ދަށުގައި މީހުން ތިބޭތަ؟"
          },
          "props": {
            "caption": {
              "en": "Yes, I do",
              "dv": "އާނއެކެވެ، ތިބެއެވެ"
            }
          }
        }
      ]
    },
    {
      "id": "p_household",
      "title": {
        "en": "Household",
        "dv": "ގޭގެ މަޢުލޫމާތު"
      },
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
          "title": {
            "en": "Dependants",
            "dv": "ބެލުމުގެ ދަށުގައިވާ މީހުން"
          },
          "columns": 2,
          "repeat": {
            "min": 1,
            "max": 6,
            "addLabel": {
              "en": "Add a dependant",
              "dv": "މީހަކު އިތުރުކުރައްވާ"
            },
            "itemLabel": {
              "en": "Dependant {n}",
              "dv": "މީހާ {n}"
            }
          },
          "elements": [
            {
              "kind": "field",
              "id": "f_dep_name",
              "type": "text",
              "key": "name",
              "label": {
                "en": "Name",
                "dv": "ނަން"
              },
              "required": true
            },
            {
              "kind": "field",
              "id": "f_dep_rel",
              "type": "select",
              "key": "relationship",
              "label": {
                "en": "Relationship",
                "dv": "ގާތްކަން"
              },
              "required": true,
              "options": [
                {
                  "id": "o_r1",
                  "value": "child",
                  "label": {
                    "en": "Child",
                    "dv": "ދަރިއެއް"
                  }
                },
                {
                  "id": "o_r2",
                  "value": "parent",
                  "label": {
                    "en": "Parent",
                    "dv": "މައިންބަފައިން"
                  }
                },
                {
                  "id": "o_r3",
                  "value": "sibling",
                  "label": {
                    "en": "Sibling",
                    "dv": "އެއްބަނޑުގެ މީހަކު"
                  }
                },
                {
                  "id": "o_r4",
                  "value": "other",
                  "label": {
                    "en": "Other",
                    "dv": "އެހެން"
                  }
                }
              ]
            },
            {
              "kind": "field",
              "id": "f_dep_other",
              "type": "text",
              "key": "relationship_other",
              "label": {
                "en": "How are you related?",
                "dv": "ތިޔަބޭފުޅާއަށް ގާތްވަނީ ކިހިނެއްތޯ؟"
              },
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
          "title": {
            "en": "Monthly household income",
            "dv": "ގޭގެ މަހުގެ އާމްދަނީ"
          },
          "columns": 3,
          "elements": [
            {
              "kind": "field",
              "id": "f_wages",
              "type": "currency",
              "key": "wages",
              "label": {
                "en": "Wages",
                "dv": "މުސާރަ"
              },
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
              "label": {
                "en": "Benefits",
                "dv": "އެހީތެރިކަން"
              },
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
              "label": {
                "en": "Total",
                "dv": "ޖުމްލަ"
              },
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
      "title": {
        "en": "Your application",
        "dv": "ތިޔަބޭފުޅާގެ އެދުން"
      },
      "elements": [
        {
          "kind": "field",
          "id": "f_prog",
          "type": "select",
          "key": "programme",
          "label": {
            "en": "Programme",
            "dv": "ޕްރޮގްރާމް"
          },
          "required": true,
          "placeholder": {
            "en": "Choose a programme",
            "dv": "ޕްރޮގްރާމެއް ހޮވާ"
          },
          "options": [
            {
              "id": "o_p1",
              "value": "stem",
              "label": {
                "en": "Science and engineering",
                "dv": "ސައިންސާއި އިންޖިނިއަރިންގ"
              }
            },
            {
              "id": "o_p2",
              "value": "arts",
              "label": {
                "en": "Arts and humanities",
                "dv": "އާޓްސް އާއި ހިއުމެނިޓީސް"
              }
            },
            {
              "id": "o_p3",
              "value": "health",
              "label": {
                "en": "Health and medicine",
                "dv": "ސިއްހަތާއި ބޭސްފަރުވާ"
              }
            },
            {
              "id": "o_p4",
              "value": "vocational",
              "label": {
                "en": "Vocational training",
                "dv": "ހުނަރުވެރިކަމުގެ ތަމްރީނު"
              }
            }
          ]
        },
        {
          "kind": "field",
          "id": "f_courses",
          "type": "multiselect",
          "key": "courses",
          "label": {
            "en": "Courses you’ll take",
            "dv": "ކިޔަވާނެ ކޯސްތައް"
          },
          "help": {
            "en": "The list follows the programme you picked. Choose up to four.",
            "dv": "ލިސްޓަކީ ތިޔަބޭފުޅުން ހޮވި ޕްރޮގްރާމާ ގުޅޭ ކޯސްތަކެވެ. ގިނަވެގެން ހަތަރު ހޮވިދާނެއެވެ."
          },
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
          "label": {
            "en": "Personal statement",
            "dv": "އަމިއްލަ ބަޔާން"
          },
          "required": true,
          "help": {
            "en": "Tell us why you are applying and what you hope to achieve. 50 to 300 words.",
            "dv": "ކީއްވެގެން އެދެނީ، ކޮން ކަމެއް ހާސިލުކުރަން އުންމީދުކުރަނީ ކަމުގެ ތަފްސީލު ލިޔުއްވާށެވެ. 50 އިން 300 ބަސްފުޅަށް."
          },
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
          "label": {
            "en": "Supporting documents",
            "dv": "ސަޕޯޓްކުރާ ޑޮކިއުމަންޓްތައް"
          },
          "props": {
            "multiple": true,
            "accept": ".pdf,image/*"
          },
          "help": {
            "en": "Transcripts or letters of reference. PDF or images, up to 5 MB each.",
            "dv": "ޓްރާންސްކްރިޕްޓް ނުވަތަ ރެފަރެންސް ލިޔުންތަކެވެ. PDF ނުވަތަ ފޮޓޯ، ކޮންމެއަކީ 5 އެމްބީ އާއި ހަމައަށް."
          },
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
          "label": {
            "en": "Declaration",
            "dv": "އިޤުރާރު"
          },
          "required": true,
          "requiredMessage": {
            "en": "You must confirm the declaration to apply.",
            "dv": "އެދުން ހުށަހެޅުމަށް އިޤުރާރު ކުރަންޖެހެއެވެ."
          },
          "props": {
            "caption": {
              "en": "The information I have given is true and complete.",
              "dv": "އަޅުގަނޑު ދެއްވި މަޢުލޫމާތަކީ ތެދު އަދި ފުރިހަމަ މަޢުލޫމާތެކެވެ."
            }
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
