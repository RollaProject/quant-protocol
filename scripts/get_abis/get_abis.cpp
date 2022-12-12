#include <filesystem>
#include <regex>
#include <fstream>
#include "simdjson.h"

auto main() -> int
{
    auto abis_directory{"../../abis/"};
    std::filesystem::create_directory(abis_directory);

    const std::regex interface_pattern{"[I]{1}[A-Z]{1}.*\\.json$"};
    const std::regex test_pattern{".*[Tt]+est.*"};
    const std::regex mock_pattern{".*[Mm]+ock.*"};
    const std::regex stdlib_pattern{".*([Ss]td+).*|.*([Vv]m+).*|.*([Cc]onsole+).*"};

    for (const auto &entry : std::filesystem::recursive_directory_iterator("../../out/"))
    {
        auto filename{entry.path().filename().string()};
        auto filepath{entry.path().string()};

        if (entry.is_regular_file() && !std::regex_match(filename, interface_pattern) && !std::regex_match(filepath, stdlib_pattern) && !std::regex_match(filepath, test_pattern) && !std::regex_match(filepath, mock_pattern))
        {
            simdjson::ondemand::parser parser;
            simdjson::padded_string json{simdjson::padded_string::load(filepath)};
            simdjson::ondemand::document artifact{parser.iterate(json)};

            std::filesystem::path abi_path{abis_directory + filename};
            std::ofstream abi_file{abi_path};

            abi_file << artifact["abi"] << std::endl;
        }
    }
}
