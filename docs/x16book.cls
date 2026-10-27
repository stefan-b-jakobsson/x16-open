% Class identification
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{x16book}[2026/01/20 Commander X16 book class]

% Load parent class
\LoadClass[10pt]{book}

% Pass options to parent class
\DeclareOption*
{\PassOptionsToClass{\CurrentOption}{book}}
\ProcessOptions\relax

% Page layout
    % 9x6in on 9.5x6.5in paper
    %\RequirePackage[paperheight=9in,paperwidth=6in]{geometry}
    %\RequirePackage[noaxes,cam,height=10in,width=7in,center]{crop}

    % 9x6in on A4 paper
    %\RequirePackage[paperheight=9in,paperwidth=6in]{geometry}
    %\RequirePackage[noaxes,cam,height=297mm,width=210mm,center]{crop}

    % 9x6in, no bleed
    \RequirePackage[paperheight=9in,paperwidth=6in]{geometry}

% Packages
\RequirePackage{fontspec}
\RequirePackage[english]{babel}
\RequirePackage{xcolor}
\RequirePackage{titlesec} % For titleformat
\RequirePackage{enumitem, calc} % For measurments
\RequirePackage{fancyhdr} % For fancy page layout
\RequirePackage{parskip}[parfill] % Paragraph spacing
\RequirePackage{tcolorbox} % For boxes
\RequirePackage{longtable}
\RequirePackage{tabularray}
\RequirePackage{listings}
\RequirePackage{csquotes}
\RequirePackage[export]{adjustbox}
\RequirePackage{afterpage}
\RequirePackage{microtype}

\setlength{\emergencystretch}{3em}

% Definitions: Fonts
\setmainfont{Futura}
\setsansfont{Futura}
\setmonofont{IBMPlexMono-Light}[
    Scale = MatchLowercase
]

% Definitions: Colors
\definecolor{x16blue}{cmyk}{1.00, 0.50, 0.00, 0.00}
%\definecolor{x16gray}{cmyk}{0.00, 0.00, 0.00, 0.20}
%\definecolor{x16darkgray}{cmyk}{0.00, 0.00, 0.00, 0.80}

% Definitions: Page format
\fancypagestyle{whitepagenum}{
    \fancyhf{}
    \renewcommand{\headrulewidth}{0pt}
    \renewcommand{\footrulewidth}{0pt}
    \fancyfoot[C]{\textcolor{white}{\thepage}}
}

% Definitions: Ensure bleed background color
\makeatletter
\let\org@set@page@color\set@page@color
\makeatother

\makeatletter
\AtBeginDocument{\let\set@page@color\org@set@page@color}
\makeatother

% Definitions: Section format
\titleformat{\chapter}[display]
    {\normalfont\sffamily\raggedleft\huge\mdseries\color{white}}
    {\chaptertitlename\ \thechapter}{20pt}{\Huge}
\titleformat{\section}
    {\normalfont\bfseries\large\color{x16blue}}{\thesection}{20pt}{}
\titleformat{\subsection}
    {\normalfont\bfseries\normalsize\color{x16blue}}{\thesubsection}{20pt}{}

\newcommand*\NoIndentAfterEnv[1]{%
  \AfterEndEnvironment{#1}{\par\@afterindentfalse\@afterheading}}
\makeatother

% Definitions: Table format
\DefTblrTemplate{firsthead, middlehead,lasthead}{default}{}

\newcommand{\discardcol}[1]{}  % Define a command that ignores its argument

% Definition: Code listing
\lstset{
    frame=single,                    % Add frame around code
    framerule=0.5pt,
    framesep=5pt,                    % Padding between frame and code
    rulecolor=\color{black},
    breaklines=true,                 % Enable automatic line breaking
    breakatwhitespace=true,          % Break at spaces when possible
    postbreak=\mbox{\textcolor{red}{$\hookrightarrow$}\space},  % Visual indicator for line continuation
    basicstyle=\ttfamily\small,
    showstringspaces=false,
    numbersep=5pt,
    tabsize=4,
    captionpos=b,
}

% Chapter environment
\newenvironment{chapterpage}[1]
    %begin
    {
        \color{white}
        \chapter{#1}
        \pagecolor{x16blue}
        \thispagestyle{whitepagenum}
    }
    %end
    {
        \color{black}
        \newpage
        \pagecolor{white}
    }

% Chapter content list
\newenvironment{chapteritems}
    %begin
    {
        \begin{itemize}[labelwidth=0.5\textwidth, leftmargin=0.5\textwidth]
    }
    %end
    {
        \end{itemize}
    }

% Box for <mark> tag
\newtcbox{\markbox}{
    on line, % This prevents line breaks
    colback=darkgray, coltext=white, 
    boxrule=0pt, arc=2pt, boxsep=1pt,
    left=1pt, right=1pt, top=3pt, bottom=1pt,
    height=2.2ex,
    valign=center,
    fontupper=\fontsize{7}{7}\selectfont,
    baseline=2pt
}

\newenvironment{x16mark}
    {
        \begin{tcolorbox}[size=\fbox]
        \ttfamily\scriptsize
        \color{white}
    }
    {
        \end{tcolorbox}
        \color{black}
   }

