from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


OUTPUT = "output/pdf/furfeel_mobile_qa_findings.pdf"

BRAND = colors.HexColor("#2563EB")
BRAND_DARK = colors.HexColor("#173B7A")
INK = colors.HexColor("#172033")
MUTED = colors.HexColor("#5F6B7A")
SOFT = colors.HexColor("#EEF5FF")
LINE = colors.HexColor("#D8E2F0")
WARN = colors.HexColor("#B45309")
HIGH = colors.HexColor("#B91C1C")


def make_styles():
    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name="TitleCustom",
            parent=styles["Title"],
            fontName="Helvetica-Bold",
            fontSize=22,
            leading=28,
            textColor=BRAND_DARK,
            alignment=TA_CENTER,
            spaceAfter=8,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Subtitle",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=10,
            leading=14,
            textColor=MUTED,
            alignment=TA_CENTER,
            spaceAfter=18,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Section",
            parent=styles["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=14,
            leading=18,
            textColor=BRAND_DARK,
            spaceBefore=12,
            spaceAfter=8,
        )
    )
    styles.add(
        ParagraphStyle(
            name="BodyCustom",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=10,
            leading=14,
            textColor=INK,
            spaceAfter=7,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Small",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=8.5,
            leading=11,
            textColor=MUTED,
        )
    )
    styles.add(
        ParagraphStyle(
            name="FindingTitle",
            parent=styles["Heading3"],
            fontName="Helvetica-Bold",
            fontSize=12,
            leading=15,
            textColor=INK,
            spaceBefore=8,
            spaceAfter=5,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Cell",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=8.5,
            leading=11,
            textColor=INK,
        )
    )
    styles.add(
        ParagraphStyle(
            name="CellBold",
            parent=styles["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=8.5,
            leading=11,
            textColor=INK,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Badge",
            parent=styles["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=8.5,
            leading=11,
            textColor=colors.white,
        )
    )
    return styles


def header_footer(canvas, doc):
    canvas.saveState()
    width, height = LETTER
    canvas.setFillColor(BRAND)
    canvas.rect(0, height - 0.28 * inch, width, 0.28 * inch, fill=1, stroke=0)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(doc.leftMargin, 0.38 * inch, "FurFeel Mobile QA Findings")
    canvas.drawRightString(width - doc.rightMargin, 0.38 * inch, f"Page {doc.page}")
    canvas.restoreState()


def bullet_list(items, styles):
    return ListFlowable(
        [ListItem(Paragraph(item, styles["BodyCustom"]), leftIndent=12) for item in items],
        bulletType="bullet",
        start="circle",
        leftIndent=18,
        bulletFontName="Helvetica",
        bulletFontSize=7,
    )


def meta_table(rows, styles):
    table = Table(
        [[Paragraph(k, styles["CellBold"]), Paragraph(v, styles["Cell"])] for k, v in rows],
        colWidths=[1.25 * inch, 4.75 * inch],
        hAlign="LEFT",
    )
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), SOFT),
                ("BOX", (0, 0), (-1, -1), 0.5, LINE),
                ("INNERGRID", (0, 0), (-1, -1), 0.35, LINE),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 7),
                ("RIGHTPADDING", (0, 0), (-1, -1), 7),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    return table


def badge(text, color, styles):
    table = Table([[Paragraph(text, styles["Badge"])]], hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), color),
                ("TEXTCOLOR", (0, 0), (-1, -1), colors.white),
                ("BOX", (0, 0), (-1, -1), 0, color),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
            ]
        )
    )
    return table


def finding_block(number, title, severity, area, severity_color, simple, rows, next_action, styles):
    return KeepTogether(
        [
            Paragraph(f"Finding {number}: {title}", styles["FindingTitle"]),
            Table(
                [[badge(f"Severity: {severity}", severity_color, styles), badge(f"Area: {area}", BRAND, styles)]],
                colWidths=[2.2 * inch, 2.2 * inch],
                hAlign="LEFT",
                style=[("VALIGN", (0, 0), (-1, -1), "MIDDLE")],
            ),
            Spacer(1, 7),
            Paragraph(f"<b>Plain explanation:</b> {simple}", styles["BodyCustom"]),
            meta_table(rows, styles),
            Spacer(1, 7),
            Paragraph(f"<b>Recommended next action:</b> {next_action}", styles["BodyCustom"]),
            Spacer(1, 8),
        ]
    )


def build():
    styles = make_styles()
    doc = BaseDocTemplate(
        OUTPUT,
        pagesize=LETTER,
        leftMargin=0.65 * inch,
        rightMargin=0.65 * inch,
        topMargin=0.68 * inch,
        bottomMargin=0.65 * inch,
        title="FurFeel Mobile QA Findings",
        author="Codex QA",
    )
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="normal")
    doc.addPageTemplates([PageTemplate(id="qa", frames=[frame], onPage=header_footer)])

    story = []
    story.append(Paragraph("FurFeel Flutter Mobile QA Findings", styles["TitleCustom"]))
    story.append(
        Paragraph(
            "Simple summary of the latest QA pass on auth boundaries, live telemetry, owner copy, and core Home flows.",
            styles["Subtitle"],
        )
    )

    story.append(Paragraph("Quick Summary", styles["Section"]))
    story.append(
        Paragraph(
            "The most important problem found is a layout overflow in the floating bottom navigation. "
            "It happens when the app reaches the main owner shell and can break widget tests before Home finishes rendering. "
            "The auth redirect boundary checks looked good in the focused tests: Google OAuth is pinned away from the dashboard domain.",
            styles["BodyCustom"],
        )
    )
    story.append(
        meta_table(
            [
                ("Highest priority", "Fix the floating navigation overflow."),
                ("Why it matters", "A tiny visual overflow can become clipped text, broken accessibility, or unstable tests on smaller screens."),
                ("Second item", "Clarify the new Updated time so users know whether it refers to vitals telemetry or the stress score."),
                ("Production data", "No production data was touched during this QA pass."),
            ],
            styles,
        )
    )

    story.append(Paragraph("What Was Checked", styles["Section"]))
    story.append(
        bullet_list(
            [
                "Google OAuth redirect logic, including checks that mobile web does not return to furfeel.site.",
                "Mobile access role guard, including admin/staff denial in the owner app.",
                "No-diagnosis copy checks for owner-facing language.",
                "Consent gate flow into the main app shell.",
                "Live telemetry timestamp display, including the new AM/PM format.",
                "Static analysis on the mobile app and focused tests.",
            ],
            styles,
        )
    )

    story.append(PageBreak())
    story.append(Paragraph("Findings", styles["Section"]))
    story.append(
        finding_block(
            1,
            "Floating bottom nav overflows on Home shell",
            "High",
            "Accessibility / UX",
            HIGH,
            "The bottom navigation is just a little too tall for the space it gives itself. "
            "Flutter reports a 2 pixel overflow. That sounds small, but it can cause clipped labels, unstable widget tests, and problems on small screens or larger text settings.",
            [
                ("Steps", "Run <b>flutter test test/consent_gate_test.dart</b> and let the app unlock into RootShell."),
                ("Expected", "The app lands on Home and shows Health overview with no layout exceptions."),
                ("Actual", "Flutter throws <b>RenderFlex overflowed by 2.0 pixels on the bottom</b>. The test then cannot find Health overview."),
                ("Evidence", "Overflow points to <b>apps/mobile/lib/widgets/floating_nav_bar.dart:192</b>. The nav surface is fixed at 64 px high at line 112, while the item contains vertical padding, icon, spacing, and a text label."),
                ("Device", "Flutter widget test environment on local macOS."),
                ("Restart", "Reproduces from a fresh test launch. Hot restart/full restart on a physical device was not tested."),
            ],
            "Reduce the vertical content inside each nav item, increase the nav surface height, or make the item layout flexible. Then rerun consent, root shell, and accessibility text-scale tests.",
            styles,
        )
    )
    story.append(
        finding_block(
            2,
            "Updated time may be unclear when telemetry and classification arrive separately",
            "Medium",
            "Home / Telemetry",
            WARN,
            "The Home hero now shows a helpful time like Updated 3:42 PM. The issue is wording: the time comes from the newest telemetry reading, but the stress score comes from a separate classification event. For a short moment, the time can update before the stress score updates.",
            [
                ("Steps", "Receive a realtime telemetry_readings insert before the matching stress_classifications insert."),
                ("Expected", "The UI makes clear whether the time refers to vitals telemetry or the stress score."),
                ("Actual", "The hero can show the previous stress level while the chip says Updated 3:42 PM from the newer reading."),
                ("Evidence", "Home passes <b>widget.reading?.capturedAt</b> into the hero at <b>apps/mobile/lib/screens/home/home_tab.dart:115</b>. Realtime subscribes to telemetry_readings and stress_classifications separately in <b>furfeel_repository.dart:880-884</b>."),
                ("Device", "Static/code QA based on realtime event ordering."),
                ("Restart", "Not restart-dependent. It depends on event ordering."),
            ],
            "Rename the chip to something more specific, such as Last vitals 3:42 PM, or show separate timestamps for vitals and stress score.",
            styles,
        )
    )

    story.append(Paragraph("Passing Checks", styles["Section"]))
    story.append(
        bullet_list(
            [
                "Google OAuth redirect tests passed, including dashboard-domain denial.",
                "Mobile access role test passed: only owner accounts are allowed into the mobile app.",
                "No-diagnosis copy test passed.",
                "Login page tests passed in the focused batch.",
                "AM/PM timestamp formatter test passed.",
                "Flutter analyze on the checked mobile files passed.",
            ],
            styles,
        )
    )

    story.append(Paragraph("Suggested Fix Order", styles["Section"]))
    story.append(
        bullet_list(
            [
                "First: fix the floating navigation overflow, because it blocks reliable Home/consent QA and can affect small screens.",
                "Second: clarify the Updated chip wording so owners do not confuse telemetry freshness with stress-score freshness.",
                "Third: rerun root_shell_test.dart, consent_gate_test.dart, a11y text scale tests, Google OAuth tests, and no-diagnosis copy tests.",
            ],
            styles,
        )
    )

    doc.build(story)


if __name__ == "__main__":
    build()
