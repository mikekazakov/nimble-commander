// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#define CATCH_CONFIG_ENABLE_BENCHMARKING
#include "Tests.h"
#include <random>
#include <fmt/format.h>
#include <sys/dirent.h>
#include <VFS/VFS.h>
#include <VFS/VFSListingInput.h>
#include "PanelData.h"
#include "PanelDataItemVolatileData.h"
#include "PanelDataSelection.h"

using namespace nc;
using namespace nc::base;
using namespace nc::panel;
using data::ItemVolatileData;
using data::Model;
using data::SortMode;

static const std::string_view g_Words[] = {"report",       "summary",     "data",
                                           "file",         "document",    "notes",
                                           "presentation", "project",     "meeting",
                                           "invoice",      "documento",   "informe",
                                           "resumen",      "archivo",     "factura",
                                           "presentacion", "proyecto",    "reunion",
                                           "nota",         "rapport",     "document",
                                           "resume",       "fichier",     "facture",
                                           "presentation", "projet",      "rencontre",
                                           "note",         "bericht",     "datei",
                                           "dokument",     "rechnung",    "zusammenfassung",
                                           "projekt",      "besprechung", "notiz",
                                           "报告",         "文件",        "数据",
                                           "计划",         "项目",        "发票",
                                           "笔记",         "会议",        "摘要",
                                           "отчет",        "документ",    "данные",
                                           "файл",         "встреча",     "проект",
                                           "счёт",         "презентация", "заметка",
                                           "レポート",     "データ",      "ファイル",
                                           "ドキュメント", "発表",        "会議",
                                           "計画",         "請求書",      "メモ",
                                           "보고서",       "데이터",      "파일",
                                           "문서",         "회의",        "계획",
                                           "프로젝트",     "송장",        "메모"};

static const std::string_view g_Extensions[] =
    {".txt", ".pdf", ".jpg", ".docx", ".png", ".csv", ".pptx", ".xlsx", ".md"};

static const std::string_view g_Punctuation = "-_@#$&!%+";
static const std::string_view g_Digits = "0123456789";

static std::string GenerateFilename(std::mt19937 &rng)
{
    std::uniform_int_distribution<> words_dist(0, std::size(g_Words) - 1);
    std::uniform_int_distribution<> extension_dist(0, std::size(g_Extensions) - 1);
    std::uniform_int_distribution<> num_digits_dist(0, 2);
    std::uniform_int_distribution<> digit_dist(0, std::size(g_Digits) - 1);
    std::uniform_int_distribution<> num_punctuations_dist(0, 2);
    std::uniform_int_distribution<> punctuation_dist(0, std::size(g_Punctuation) - 1);
    std::uniform_int_distribution<> num_base_words_dist(1, 2);

    std::string filename = std::string(g_Words[words_dist(rng)]);

    const int num_base_words = num_base_words_dist(rng);
    if( num_base_words == 2 ) {
        std::uniform_int_distribution<> separator_dist(0, 2);
        std::string separator = (separator_dist(rng) == 0) ? "_" : ((separator_dist(rng) == 1) ? "-" : " ");
        filename += separator;
        filename += g_Words[words_dist(rng)];
    }

    const int num_digits = num_digits_dist(rng);
    for( int i = 0; i < num_digits; ++i ) {
        filename += g_Digits[digit_dist(rng)];
    }

    const int num_punctuations = num_punctuations_dist(rng);
    for( int i = 0; i < num_punctuations; ++i ) {
        filename += g_Punctuation[punctuation_dist(rng)];
    }

    filename += g_Extensions[extension_dist(rng)];
    return filename;
}

static VFSListingPtr ProduceDummyListing(const std::vector<std::string> &_filenames)
{
    vfs::ListingInput l;

    l.directories.reset(variable_container<>::type::common);
    l.directories[0] = "/";

    l.hosts.reset(variable_container<>::type::common);
    l.hosts[0] = VFSHost::DummyHost();

    for( auto &i : _filenames ) {
        l.filenames.emplace_back(i);
        l.unix_modes.emplace_back(0);
        l.unix_types.emplace_back(0);
    }

    return VFSListing::Build(std::move(l));
}

TEST_CASE("Sorting performace test")
{
    std::mt19937 rng(42);
    std::vector<std::string> filenames;
    for( int i = 0; i < 1'000; ++i ) {
        filenames.push_back(GenerateFilename(rng));
    }

    auto listing = ProduceDummyListing(filenames);
    Model model;

    SortMode mode;
    mode.sort = SortMode::Mode::SortByName;
    BENCHMARK("Case-sensitive")
    {
        mode.collation = SortMode::Collation::CaseSensitive;
        model.SetSortMode(mode);
        model.Load(listing, Model::PanelType::Directory);
        return model.RawEntriesCount();
    };
    BENCHMARK("Case-insensitive")
    {
        mode.collation = SortMode::Collation::CaseInsensitive;
        model.SetSortMode(mode);
        model.Load(listing, Model::PanelType::Directory);
        return model.RawEntriesCount();
    };
    BENCHMARK("Natural")
    {
        mode.collation = SortMode::Collation::Natural;
        model.SetSortMode(mode);
        model.Load(listing, Model::PanelType::Directory);
        return model.RawEntriesCount();
    };
}
