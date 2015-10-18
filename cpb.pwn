/* *-----------------------------------------------------------------------------------*
    _____                                  ______                             _
   |  ___|                                |  __  |                           | |
   | |       ___   ____  _____    ___     | |__| |  ____   ____     ___   ___| |    ___
   | |     / _  | |  _/ |  _  | / _  |    |  ____| |  __) |  __|  / _  | |  _  |  / _  |
   | |    | | | | | |   | | | || | | |    | |      | |__  | |__  | | | | | | | | | | | |
   | |    | | | | | |   | | | || | | |    | |      |  __) |__  | | | | | | | | | | | | |
   | |___ | |_| | | |   | |_| || |_| |    | |      | |__   __| | | |_| | | |_| | | |_| |
   |_____| \__,_| |_|   \___  | \__,_|    |_|      |____) |____|  \__,_| \_____|  \__,_|
						 ___/ |
		 				|____/
						  ______                        _   _
   					     |  __  |                      |_| | |
   						 | |  | |  ____    ___   ____   _  | |
   						 | |__| | |  _/  / _  | |  __| | | | |
   						 |  __ (  | |   | | | | | |__  | | | |
						 | |  | | | |   | | | | |__  | | | | |
   						 | |__| | | |   | |_| |  __| | | | | |
   						 |______| |_|    \__,_| |____| |_| |_|
   *-----------------------------------------------------------------------------------*
									   ATENÇÃO
					Ao usar esse gamemode, favor manter os créditos.
*/
#include <a_samp>
#include <zcmd>
#include <sscanf2>
#include <a_mysql>
#include <streamer>

#define Host_MySQL "localhost"
#define Usuario_MySQL "root"
#define Database_MySQL ""
#define Senha_MySQL ""

enum
{
	DialogoLogin,
	DialogoRegistro
};

new
	mysql;

native WP_Hash(buffer[], len, const str[]);

enum pInfo
{
	pID,
	pNome[MAX_PLAYER_NAME],
    pSenha,
    pAdmin,
    pDinheiro,
    pIP,
    pClasse,
    pPontos,
    bool:pLogado,
    bool:pTrabalhando,
    MsgBoasVindas,
    gSpectateID,
    gSpectateType,
    CargaID,
    Carregamento,
    Descarregamento,
    PartedoTrabalho,
    VeiculoID,
    TrailerID,
    TempoCargaDescarga
}
new PlayerInfo[MAX_PLAYERS][pInfo];

#define CaminhaoMinerio 1
#define CaminhaoFluido 2
#define CaminhaoFechado 3

enum Local_CargaDescarga
{
	NomedoLocal[50],
	Float:LocX,
	Float:LocY,
	Float:LocZ
}


new LocalCargaDescarga[][Local_CargaDescarga] =
{
	// Local, FloatX, FloatY, FloatZ
	{"Dummy location", 0.0, 0.0, 0.0},
	{"Loja de Bebidas de Los Santos", 2337.0, -1371.1, 24.0}, // Local 1
	{"Rodriguez Ferro e Aço", 2443.4, -1426.1, 24.0}, // Local 2
	{"Lava Jato de Los Santos", 2511.4, -1468.6, 24.0}, // Local 3
	{"Estádio de Los Santos", 2802.0, -1818.2, 9.9} // Local 4
};

enum TCarga
{
	LoadName[50],
	Float:PayPerUnit,
	PCV_Required,
	FromLocations[30],
	ToLocations[30]
}

new ACarga[][TCarga] =
{
	// Nome da Carga, Preço por metro, Veículo que precisa, Local que pega, Local que entrega
	{"Dummy", 0.00, 0, {0}, {0}},

	// Cargas de Trailer com Minério
	{"Cascalho", 1.00, CaminhaoMinerio, {1}, {2, 3}}, // CargaID 1

	// Cargas de Trailer de Flúidos
	{"Leite", 1.00, CaminhaoFluido, {1}, {2, 3}}, // CargaID 2

	// Cargas de Trailer Fechado
	{"Comida enlatada", 1.00, CaminhaoFechado, {1}, {2, 3}}, // CargaID 3
 	{"Cerveja", 1.00, CaminhaoFechado, {1}, {2, 3}} // CargaID 4
};

stock Product_GetList(PCV_Needed, &NumProducts)
{
	new ListadeProdutos[50];
	for (new i; i < sizeof(ACarga); i++)
	{
		if (NumProducts < 50)
		{
			if (ACarga[i][PCV_Required] == PCV_Needed)
			{
				ListadeProdutos[NumProducts] = i;
				NumProducts++;
			}
		}
	}
	return ListadeProdutos;
}

#define COR_BRANCO 0xFFFFFFFF
#define COR_VERMELHO 0xFF0000AA
#define COR_AZUL 0x00BFFFFF
#define COR_AMARELO 0xFFFF00FF
#define COR_CINZA 0xAFAFAFAA
#define COR_ROSA 0xFF00FFFF
#define COR_ROSACLARO 0xFF8CFFFF

#define Caminhoneiro 1
#define Policia 2
#define Mecanico 3
#define MotoristadeOnibus 4

#define CorCaminhoneiro 0xFFFF00FF
#define CorPolicia 0x0000FFFF
#define CorMecanico 0xFFA500FF
#define CorOnibus 0x00FF00FF

#define TrailerFluidos 584
#define TrailerFechado1 435
#define TrailerFechado2 591
#define TrailerMinerio 450

#define VeiculoRoadTrain 515
#define VeiculoLineRunner 403
#define VeiculoTanker 514

#define DialogoCaminhaoCarga 997
#define DialogoCaminhaoCarregamento 998
#define DialogoCaminhaoDescarregamento 999

#define ADMIN_SPEC_TYPE_NONE 0
#define ADMIN_SPEC_TYPE_PLAYER 1
#define ADMIN_SPEC_TYPE_VEHICLE 2

forward Mensagens();

new mensagens[8][128] = {
"[Dica] Evite ficar de ESC por muito tempo enquanto estiver com trailer, você pode perdê-lo!",
"[Aviso] Leia sempre as /regras. Elas podem ser atualizadas à qualquer momento!",
"[Dica] Dirija sempre pelo lado direito da rua/estrada. Você pode ser punido caso desrespeite!",
"[Aviso] Não bata no veículo de outro player de propósito, você será punido!",
"[Aviso] Viu alguém fazendo alguma coisa errada? Use /reportar.",
"[Dica] Viu alguém fazendo alguma coisa errada e não tem admin on? Denuncie no fórum!",
"[Dica] Digite /admins para ver os administradores online.",
"[Aviso] Não desrespeite as /regras do servidor, você será punido!"
};

new Text: LogoC;
new Text: LogoP;
new Text: LogoB;
new Text: SiteCPB;
new Text: DataeHora;
new Text: Carregando;
new Text: Carregando1;
new Text: Carregando2;
new Text: Carregando3;
new Text: Velocimetro;
new Text: DinheiroR;

forward Velocidade();

enum time_data
{
	dDay,
	dYear,
	dMonth,
	tSecond,
	tMinute,
	tHour,
}
new ClockTime[time_data];
forward SyncClock(playerid);

main()
{
	print("\n--------------------------------------------------------");
	print("                 Carga Pesada Brasil\n");
	print("            Versão inicial por: Galhardo.");
	print("            Todos os direitos reservados.");
	print("     Ao utilizar o gamemode favor manter os créditos.");
	print("--------------------------------------------------------\n");
}

enum LocalSpawn
{
	Float:SpawnX,
	Float:SpawnY,
	Float:SpawnZ,
	Float:SpawnAngle
}

new SpawnPolicial[][LocalSpawn] =
{
	{2268.0703,2447.9590,3.5313,180.0},
	{1525.7537,-1677.8368,5.8906,270.0},
	{-1606.2336,673.7987,-5.2422,0.0}
};

new SpawnCaminhao25pontos[][LocalSpawn] =
{
	{2813.7598,892.8499,10.7578,0.0000}
};

new SpawnCaminhao50pontos[][LocalSpawn] =
{
	{1639.8845,2307.7581,10.8203,90.000},
	{-2029.8754,-122.7093,35.1950,180.0000},
	{-50.7697,-232.1554,6.7646,0.000},
	{2183.6555,-2259.8906,13.3995,225.000}
};

new SpawnCaminhao75pontos[][LocalSpawn] =
{
	{1163.8113,1983.8318,10.8203,270.0000},
	{2644.2668,-2141.1602,17.5453,0.0000}
};

new SpawnCaminhao75maispontos[][LocalSpawn] =
{
	{1163.8113,1983.8318,10.8203,270.0000},
	{2644.2668,-2141.1602,17.5453,0.0000}
};

static const Pontos[][128] = {
{"  "},
{"  "},
{"{FF0000}Pontos para veículos{00BFFF}"},
{"Pontos = Veículos"},
{"0 até 24 = Mule, Benson, Boxville e Rumpo."},
{"25 até 49 = Linerunner e Burrito."},
{"50 até 74 = Tanker e Yankee."},
{"75+ = Roadtrain."},
{"  "},
{"{FF0000}Pontos para classe{00BFFF}"},
{"Classe = Pontos"},
{"Caminhoneiro = 0+ pontos."},
{"Polícia = 25+ pontos."},
{"Motorista de Ônibus = 15+ pontos"},
{"Máfia = 50+ pontos  "},
{"Mecânico = 10+ pontos"}
};

static const TabelaCmds[][128] = {
{" "},
{"{FF0000}/reportar{FFFF00} = Reportar algum player infrator"},
{"{FF0000}/t{FFFF00} = Desatracar o trailer"},
{"{FF0000}/admins{FFFF00} = Ver os administradores online e seus cargos"},
{"{FF0000}/pontos{FFFF00} = Ver a tabela de pontos para os caminhões"},
{"{FF0000}/girar{FFFF00} = Girar um caminhão tombado"},
{"{FF0000}/kill{FFFF00} = Se matar"},
{"{FF0000}/mudar{FFFF00} = Mudar a sua classe ou skin"},
{"{FF0000}/trabalhar{FFFF00} = Começar um trabalho"}
};

static const AdminCmds[][128] = {
{" "},
{"{FF0000}/spec{FFFF00} = Espiar algum player reportado ou não"},
{"{FF0000}/an{FFFF00} = Fazer anúncios (mensagem de cor rosa, para destacar)"},
{"{FF0000}/kick{FFFF00} = Kickar um player infrator"},
{"{FF0000}/ban{FFFF00} = Banir um player infrator"},
{"{FF0000}/girar{FFFF00} = Girar um caminhão tombado"},
{"{FF0000}/kill{FFFF00} = Se matar"},
{"{FF0000}/mudar{FFFF00} = Mudar a sua classe ou skin"},
{"{FF0000}/trabalhar{FFFF00} = Começar um trabalho"},
{"{FF0000}/spawncarro{FFFF00} = Spawnar um carro (precisa estar dentro)"},
{"{FF0000}/ip{FFFF00} = Ver o IP de um player"}
};

static const RegrasAdmin[][180] = {
{" "},
{"{FF0000}Respeite TODAS essas regras ou poderá levar aviso, ser rebaixado, expulso ou levar BAN!"},
{" "},
{"{FFFFFF}- Não desrespeite nenhum player, principalmente, nenhum administrador. ({AFAFAF}AVISO{FFFFFF})"},
{"{FFFFFF}- Você tem seu tempo para jogar, mais também não foque somente em jogar, lembre-se que você também é ADMINISTRADOR! ({AFAFAF}AVISO{FFFFFF})"},
{"{FFFFFF}- Não abuse dos comandos (/kick, /ban, /an). ({AFAFAF}AVISO{FFFFFF}/{AFAFAF}REBAIXAMENTO{FFFFFF}/{AFAFAF}EXPULSÃO{FFFFFF})"},
{"{FFFFFF}- Não abuse da autoridade, você é administrador, não o dono do mundo! ({AFAFAF}AVISO{FFFFFF}/{AFAFAF}REBAIXAMENTO{FFFFFF}/{AFAFAF}EXPULSÃO{FFFFFF})"},
{"{FFFFFF}- Somente punir com provas. Se tiver com dúvida na hora de punir, converse com outro administrador. ({AFAFAF}AVISO{FFFFFF}/{AFAFAF}REBAIXAMENTO{FFFFFF})"},
{"{FFFFFF}- Não ter contas fakes. ({AFAFAF}AVISO{FFFFFF})"},
{"{FFFFFF}- Não misturar amizade com administração. Se um amigo seu fazer algo de errado, puna-o! ({AFAFAF}AVISO{FFFFFF}/{AFAFAF}REBAIXAMENTO{FFFFFF})"},
{"{FFFFFF}- Não ficar utilizando o comando /an toda hora, somente para fazer anúncios importantes! ({AFAFAF}AVISO{FFFFFF})"},
{"{FFFFFF}- Não discuta no chat. ({AFAFAF}AVISO{FFFFFF}/{AFAFAF}REBAIXAMENTO{FFFFFF}/{AFAFAF}EXPULSÃO{FFFFFF})"},
{"{FFFFFF}- Ao ver algum outro administrador abusando de comandos dê F8 e repasse para um Fundador! ({AFAFAF}AVISO{FFFFFF}/{AFAFAF}REBAIXAMENTO{FFFFFF}/{AFAFAF}EXPULSÃO{FFFFFF})"}
};

static const Bemvindo[16][128] = {
{"{FFFFFF}Seja bem vindo ao {FFFF00}Carga Pesada Brasil{FFFFFF}."},
{""},
{"O Carga Pesada Brasil teve seu gamemode feito do 0 por {FFFF00}Galhardo{FFFFFF}."},
{""},
{"Como é a primeira vez que você loga no servidor, é bom saber algumas coisas que são importante para um iniciante."},
{""},
{"{FFFF00}Primeiro{FFFFFF}: {FF0000}NUNCA REVELE SUA SENHA PARA NINGUÉM{FFFFFF}."},
{"Não nos responsabilizamos por contas hackeadas!"},
{""},
{"{FFFF00}Segundo{FFFFFF}: Aqui no Carga Pesada Brasil nós temos um sistema que restringe certos caminhões à uma certa pontuação,"},
{"ou seja, você é iniciante (0 pontos) e terá que utilizar somente caminhões pequenos, até adquirir mais experiência e pontos"},
{"para ir subindo o nível dos caminhões, até chegar no melhor caminhão do jogo, o RoadTrain, com 75 pontos."},
{"Qualquer dúvida sobre a restrição de pontos para caminhões digite /pontos."},
{""},
{"Tenha um bom jogo!"},
{"Equipe {66FF00FF}CPB."}
};

public OnGameModeInit()
{
    mysql_log(LOG_ALL);
    mysql = mysql_connect(Host_MySQL, Usuario_MySQL, Database_MySQL, Senha_MySQL);
    if(mysql_errno() != 0)
    {
        printf("[MySQL] Conexão com banco de dados MySQL FALHOU.");
    }
    else
    {
        printf("[MySQL] Conexão com banco de dados MySQL foi autenticada.");
    }
	SetGameModeText("Carga Pesada v1.0");
	SendRconCommand("mapname CPB (c)");
	UsePlayerPedAnims();
	DisableInteriorEnterExits();
	EnableStuntBonusForAll(0);
	ShowPlayerMarkers(1);
	ShowNameTags(1);
	/*AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA*/
	CreateObject(8661,1887.9000000,-1421.3000000,569.5999800,0.0000000,0.0000000,0.0000000); //object(gnhtelgrnd_lvs) (1)
	CreateObject(3612,1876.3000000,-1434.6000000,581.0000000,0.0000000,0.0000000,90.0000000); //object(hillhouse12_la) (1)
	CreateObject(3612,1893.3000000,-1434.6000000,581.0000000,0.0000000,0.0000000,90.0000000); //object(hillhouse12_la) (2)
	CreateObject(3612,1910.3000000,-1434.6000000,581.0000000,0.0000000,0.0000000,90.0000000); //object(hillhouse12_la) (3)
	CreateObject(3612,1911.0000000,-1406.0000000,581.0000000,0.0000000,0.0000000,180.0000000); //object(hillhouse12_la) (4)
	CreateObject(3612,1911.0000000,-1422.9004000,581.0000000,0.0000000,0.0000000,179.9950000); //object(hillhouse12_la) (5)
	CreateObject(3612,1872.6000000,-1422.5000000,581.4000200,0.0000000,0.0000000,0.0000000); //object(hillhouse12_la) (7)
	CreateObject(3612,1899.0000000,-1410.7998000,581.4000200,0.0000000,0.0000000,270.0000000); //object(hillhouse12_la) (8)
	CreateObject(3612,1881.9961000,-1410.7998000,581.4000200,0.0000000,0.0000000,270.0000000); //object(hillhouse12_la) (9)
	CreateObject(6300,1878.6000000,-1428.0000000,586.0000000,180.0000000,0.0000000,0.0000000); //object(pier04_law2) (1)
	CreateObject(3029,1887.0000000,-1430.9600000,569.5999800,0.0000000,0.0000000,90.0000000);
	/*AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA*/
	CreateVehicle(520,2812.8999023,910.7999878,11.6999998,0.0000000,-1,-1,-1);
	CreateVehicle(596,1538.8000488,-1644.6999512,5.6999998,180.0000000,79,1,-1);
	CreateVehicle(596,1534.5999756,-1644.6999512,5.6999998,180.0000000,79,1,-1);
	CreateVehicle(596,1530.5000000,-1644.6999512,5.6999998,180.0000000,79,1,-1);
	CreateVehicle(596,1545.3000488,-1651.0000000,5.6999998,90.0000000,79,1,-1);
	CreateVehicle(596,1545.3000488,-1655.0000000,5.6999998,90.0000000,79,1,-1);
	CreateVehicle(596,1545.3000488,-1659.0000000,5.6999998,90.0000000,79,1,-1);
	CreateVehicle(596,1545.3000488,-1663.0000000,5.6999998,90.0000000,79,1,-1);
	CreateVehicle(596,1545.3000488,-1667.9000244,5.6999998,90.0000000,79,1,-1);
	CreateVehicle(596,1545.3000488,-1672.0000000,5.6999998,90.0000000,79,1,-1);
	CreateVehicle(596,1545.3000488,-1676.0999756,5.6999998,90.0000000,79,1,-1);
	CreateVehicle(596,1545.3000488,-1680.3000488,5.6999998,90.0000000,79,1,-1);
	CreateVehicle(596,1545.3000488,-1684.3000488,5.6999998,90.0000000,79,1,-1);
	CreateVehicle(596,1526.5000000,-1644.6999512,5.6999998,180.0000000,79,1,-1);
	CreateVehicle(599,1584.1999512,-1667.5000000,6.0700002,270.0000000,79,1,-1);
	CreateVehicle(599,1584.1999512,-1671.5999756,6.0700002,270.0000000,79,1,-1);
	CreateVehicle(599,1584.1999512,-1675.9000244,6.0700002,270.0000000,79,1,-1);
	CreateVehicle(599,1584.1999512,-1679.5999756,6.0700002,270.0000000,79,1,-1);
	CreateVehicle(523,1603.9000244,-1707.5999756,5.5999999,50.0000000,79,1,-1);
	CreateVehicle(523,1604.0000000,-1709.9000244,5.5999999,50.0000000,79,1,-1);
	CreateVehicle(523,1603.3000488,-1711.5999756,5.5999999,50.0000000,79,1,-1);
	CreateVehicle(414,2160.6999512,-2278.8000488,13.5000000,225.0000000,79,1,-1);
	CreateVehicle(414,2158.1000977,-2281.3999023,13.5000000,225.0000000,79,1,-1);
	CreateVehicle(440,2152.1000977,-2290.0000000,13.6000004,225.0000000,79,1,-1);
	CreateVehicle(440,2154.1999512,-2287.8999023,13.6000004,225.0000000,79,1,-1);
	CreateVehicle(414,2163.3000488,-2276.1999512,13.5000000,225.0000000,79,1,-1);
	CreateVehicle(414,2165.8000488,-2273.8000488,13.5000000,225.0000000,79,1,-1);
	CreateVehicle(499,2168.6999512,-2271.3999023,13.5000000,225.0000000,79,1,-1);
	CreateVehicle(499,2171.3000488,-2268.8000488,13.5000000,225.0000000,79,1,-1);
	CreateVehicle(499,2173.8999023,-2266.1999512,13.5000000,225.0000000,79,1,-1);
	CreateVehicle(498,2162.3000488,-2302.1000977,13.8000002,315.0000000,79,1,-1);
	CreateVehicle(498,2165.6000977,-2305.3000488,13.8000002,315.0000000,79,1,-1);
	CreateVehicle(498,2168.8999023,-2308.5000000,13.8000002,315.0000000,79,1,-1);
	CreateVehicle(498,2172.1999512,-2311.6999512,13.8000002,315.0000000,79,1,-1);
	CreateVehicle(450,2229.0000000,-2252.0000000,14.1999998,45.0000000,79,1,-1);
	CreateVehicle(450,2234.0000000,-2247.1999512,14.1999998,45.0000000,79,1,-1);
	CreateVehicle(584,2222.6000977,-2260.2599512,14.6999998,45.0000000,79,1,-1);
	CreateVehicle(584,2220.1100977,-2262.7499512,14.6999998,45.0000000,79,1,-1);
	CreateVehicle(435,2248.3000488,-2233.3999023,14.1999998,45.0000000,79,1,-1);
	CreateVehicle(435,2244.3999023,-2237.3000488,14.1999998,45.0000000,79,1,-1);
	CreateVehicle(435,2241.6000977,-2240.0000000,14.1999998,45.0000000,79,1,-1);
	CreateVehicle(450,2236.5740000,-2244.5250000,14.1999998,45.0000000,79,1,-1);
	CreateVehicle(584,2227.5070488,-2255.0760488,14.6000004,45.0000000,79,1,-1);
	CreateVehicle(482,2216.6999512,-2268.6000977,13.8000002,45.0000000,79,1,-1);
	CreateVehicle(482,2214.3400879,-2270.8999023,13.8000002,45.0000000,79,1,-1);
	CreateVehicle(482,2209.3000488,-2276.0000000,13.8000002,45.0000000,79,1,-1);
	CreateVehicle(482,2206.8000488,-2278.5000000,13.8000002,45.0000000,79,1,-1);
	CreateVehicle(482,2202.3999023,-2281.6000977,13.8000002,45.0000000,79,1,-1);
	CreateVehicle(482,2200.1999512,-2283.8000488,13.8000002,45.0000000,79,1,-1);
	CreateVehicle(403,2188.8999023,-2228.5000000,14.1999998,225.0000000,79,1,-1);
	CreateVehicle(403,2192.0000000,-2225.3999023,14.1999998,225.0000000,79,1,-1);
	CreateVehicle(403,2196.1000977,-2221.3999023,14.3000002,225.0000000,79,1,-1);
	CreateVehicle(403,2199.3999023,-2218.1000977,14.3000002,225.0000000,79,1,-1);
	CreateVehicle(403,2203.5000000,-2214.1999512,14.1999998,225.0000000,79,1,-1);
	CreateVehicle(403,2206.8000488,-2210.8999023,14.1999998,225.0000000,79,1,-1);
	CreateVehicle(403,2210.8999023,-2207.6000977,14.1999998,225.0000000,79,1,-1);
	CreateVehicle(403,2214.0000000,-2204.5000000,14.1999998,225.0000000,79,1,-1);
	CreateVehicle(403,2216.6999512,-2201.8000488,14.1999998,225.0000000,79,1,-1);
	CreateVehicle(515,2629.8999023,-2110.0000000,14.6999998,270.0000000,6,6,-1);
	CreateVehicle(515,2629.8999023,-2105.0000000,14.6999998,270.0000000,6,6,-1);
	CreateVehicle(515,2629.8999023,-2100.0000000,14.6999998,270.0000000,6,6,-1);
	CreateVehicle(515,2629.8999023,-2095.0000000,14.6999998,270.0000000,6,6,-1);
	CreateVehicle(515,2629.8999023,-2090.0000000,14.6999998,270.0000000,6,6,-1);
	CreateVehicle(482,2700.0000000,-2116.0000000,13.8000002,90.0000000,6,1,-1);
	CreateVehicle(482,2700.0000000,-2128.0000000,13.8000002,90.0000000,6,1,-1);
	CreateVehicle(482,2700.0000000,-2124.0000000,13.8000002,90.0000000,6,1,-1);
	CreateVehicle(482,2700.0000000,-2120.0000000,13.8000002,90.0000000,6,1,-1);
	CreateVehicle(482,2700.0000000,-2112.0000000,13.8000002,90.0000000,6,1,-1);
	CreateVehicle(456,2698.0000000,-2108.0000000,13.8000002,90.0000000,6,6,-1);
	CreateVehicle(456,2698.0000000,-2104.0000000,13.8000002,90.0000000,6,6,-1);
	CreateVehicle(456,2698.0000000,-2100.0000000,13.8000002,90.0000000,6,6,-1);
	CreateVehicle(456,2698.0000000,-2096.0000000,13.8000002,90.0000000,6,6,-1);
	CreateVehicle(456,2698.0000000,-2092.0000000,13.8000002,90.0000000,6,6,-1);
	CreateVehicle(414,2699.1000977,-2088.0000000,13.6999998,90.0000000,6,6,-1);
	CreateVehicle(414,2699.1000977,-2084.0000000,13.6999998,90.0000000,6,6,-1);
	CreateVehicle(414,2699.1000977,-2080.0000000,13.6999998,90.0000000,6,6,-1);
	CreateVehicle(414,2699.1000977,-2076.0000000,13.6999998,90.0000000,6,6,-1);
	CreateVehicle(414,2699.1000977,-2072.0000000,13.6999998,90.0000000,6,6,-1);
	CreateVehicle(514,2630.5000000,-2085.0000000,14.1999998,270.0000000,6,6,-1);
	CreateVehicle(514,2630.5000000,-2080.0000000,14.1999998,270.0000000,6,6,-1);
	CreateVehicle(514,2630.5000000,-2075.0000000,14.1999998,270.0000000,6,6,-1);
	CreateVehicle(514,2630.5000000,-2070.0000000,14.1999998,270.0000000,6,6,-1);
	CreateVehicle(403,2645.0000000,-2071.0000000,14.1999998,180.0000000,6,6,-1);
	CreateVehicle(403,2650.0000000,-2071.0000000,14.1999998,180.0000000,6,6,-1);
	CreateVehicle(403,2655.0000000,-2071.0000000,14.1999998,180.0000000,6,6,-1);
	CreateVehicle(403,2660.0000000,-2071.0000000,14.1999998,180.0000000,6,6,-1);
	CreateVehicle(403,2665.0000000,-2071.0000000,14.1999998,180.0000000,6,6,-1);
	CreateVehicle(440,2690.0000000,-2070.0000000,13.8000002,180.0000000,6,6,-1);
	CreateVehicle(440,2686.0000000,-2070.0000000,13.8000002,180.0000000,6,6,-1);
	CreateVehicle(440,2682.0000000,-2070.0000000,13.8000002,180.0000000,6,6,-1);
	CreateVehicle(440,2678.0000000,-2070.0000000,13.8000002,180.0000000,6,6,-1);
	CreateVehicle(440,2674.0000000,-2070.0000000,13.8000002,180.0000000,6,6,-1);
	CreateVehicle(403,2670.0000000,-2071.0000000,14.1609087,180.0000000,6,1,-1);
	CreateVehicle(435,2430.0000000,-2114.0000000,14.1999998,0.0000000,6,6,-1);
	CreateVehicle(435,2436.0000000,-2114.0000000,14.1999998,0.0000000,6,6,-1);
	CreateVehicle(435,2442.0000000,-2114.0000000,14.1999998,0.0000000,6,6,-1);
	CreateVehicle(435,2448.0000000,-2114.0000000,14.1999998,0.0000000,6,6,-1);
	CreateVehicle(435,2454.0000000,-2114.0000000,14.1999998,0.0000000,6,6,-1);
	CreateVehicle(450,2460.0000000,-2114.0000000,14.1999998,0.0000000,6,6,-1);
	CreateVehicle(450,2466.0000000,-2114.0000000,14.1999998,0.0000000,6,6,-1);
	CreateVehicle(450,2472.0000000,-2114.0000000,14.1999998,0.0000000,6,6,-1);
	CreateVehicle(450,2478.0000000,-2114.0000000,14.1999998,0.0000000,6,6,-1);
	CreateVehicle(450,2484.0000000,-2114.0000000,14.1999998,0.0000000,6,6,-1);
	CreateVehicle(584,2490.0000000,-2114.0000000,14.6999998,0.0000000,6,6,-1);
	CreateVehicle(584,2496.0000000,-2114.0000000,14.6999998,0.0000000,6,6,-1);
	CreateVehicle(584,2502.0000000,-2114.0000000,14.6999998,0.0000000,6,6,-1);
	CreateVehicle(584,2508.0000000,-2114.0000000,14.6999998,0.0000000,6,6,-1);
	CreateVehicle(584,2514.0000000,-2114.0000000,14.6999998,0.0000000,6,6,-1);
	CreateVehicle(456,1167.0000000,2035.0000000,11.1000004,270.0000000,3,3,-1);
	CreateVehicle(456,1167.0000000,2030.0000000,11.1000004,270.0000000,3,3,-1);
	CreateVehicle(456,1167.0000000,2025.0000000,11.1000004,270.0000000,3,3,-1);
	CreateVehicle(456,1167.0000000,2020.0000000,11.1000004,270.0000000,3,3,-1);
	CreateVehicle(456,1167.0000000,2015.0000000,11.1000004,270.0000000,3,3,-1);
	CreateVehicle(414,1165.8000488,2010.0000000,11.0000000,270.0000000,3,3,-1);
	CreateVehicle(414,1165.8000488,2005.0000000,11.0000000,270.0000000,3,3,-1);
	CreateVehicle(414,1165.8000488,2000.0000000,11.0000000,270.0000000,3,3,-1);
	CreateVehicle(414,1165.8000488,1995.0000000,11.0000000,270.0000000,3,3,-1);
	CreateVehicle(414,1165.8000488,1990.0000000,11.0000000,270.0000000,3,3,-1);
	CreateVehicle(499,1120.0000000,1975.0000000,10.8999996,180.0000000,3,3,-1);
	CreateVehicle(499,1124.0000000,1975.0000000,10.8999996,180.0000000,3,3,-1);
	CreateVehicle(499,1128.0000000,1975.0000000,10.8999996,180.0000000,3,3,-1);
	CreateVehicle(499,1132.0000000,1975.0000000,10.8999996,180.0000000,3,3,-1);
	CreateVehicle(499,1136.0000000,1975.0000000,10.8999996,180.0000000,3,3,-1);
	CreateVehicle(440,1140.0000000,1975.5000000,11.0000000,180.0000000,3,3,-1);
	CreateVehicle(440,1144.0000000,1975.5000000,11.0000000,180.0000000,3,3,-1);
	CreateVehicle(440,1148.0000000,1975.5000000,11.0000000,180.0000000,3,3,-1);
	CreateVehicle(440,1152.0000000,1975.5000000,11.0000000,180.0000000,3,3,-1);
	CreateVehicle(440,1156.0000000,1975.5000000,11.0000000,180.0000000,3,3,-1);
	CreateVehicle(482,1120.8000488,1965.0000000,11.1000004,270.0000000,3,3,-1);
	CreateVehicle(482,1120.8000488,1961.0000000,11.1000004,270.0000000,3,3,-1);
	CreateVehicle(482,1120.8000488,1957.0000000,11.1000004,270.0000000,3,3,-1);
	CreateVehicle(482,1120.8000488,1953.0000000,11.1000004,270.0000000,3,3,-1);
	CreateVehicle(482,1120.8000488,1949.0000000,11.1000004,270.0000000,3,3,-1);
	CreateVehicle(482,1120.8000488,1945.0000000,11.1000004,270.0000000,3,3,-1);
	CreateVehicle(482,1120.8000488,1941.0000000,11.1000004,270.0000000,3,3,-1);
	CreateVehicle(437,2645.0000000,-2243.8000488,13.8000002,45.0000000,6,0,-1);
	CreateVehicle(437,2652.0000000,-2243.8000488,13.8000002,45.0000000,6,0,-1);
	CreateVehicle(437,2659.0000000,-2243.8000488,13.8000002,45.0000000,6,0,-1);
	CreateVehicle(437,2666.0000000,-2243.8000488,13.8000002,42.0000000,6,0,-1);
	CreateVehicle(437,2673.0000000,-2243.8000488,13.8000002,42.0000000,6,0,-1);
	CreateVehicle(437,2680.0000000,-2243.8000488,13.8000002,45.0000000,6,0,-1);
	CreateVehicle(437,2687.0000000,-2243.8000488,13.8000002,45.0000000,6,0,-1);
	CreateVehicle(437,2694.0000000,-2243.8000488,13.8000002,45.0000000,6,0,-1);
	CreateVehicle(437,2701.1999512,-2243.8000488,13.8000002,45.0000000,6,0,-1);
	CreateVehicle(437,2708.0000000,-2243.8000488,13.8000002,45.0000000,6,0,-1);
	CreateVehicle(437,2715.0000000,-2243.8000488,13.8000002,45.0000000,6,0,-1);
	CreateVehicle(437,2722.0000000,-2243.8000488,13.8000002,45.0000000,6,0,-1);
	CreateVehicle(437,2729.0000000,-2243.8000488,13.8000002,45.0000000,6,0,-1);
	CreateVehicle(437,2736.0000000,-2243.7998047,13.8000002,45.0000000,6,0,-1);
	CreateVehicle(437,2743.0000000,-2243.7998047,13.8000002,45.0000000,6,0,-1);
	CreateVehicle(437,2750.0000000,-2243.7998047,13.8000002,45.0000000,6,0,-1);
	CreateVehicle(437,2757.0000000,-2243.7998047,13.8000002,45.0000000,6,0,-1);
	CreateVehicle(431,2757.0000000,-2187.5000000,13.8000002,134.9998779,6,0,-1);
	CreateVehicle(431,2750.0000000,-2187.5000000,13.8000002,134.9999390,6,0,-1);
	CreateVehicle(431,2743.0000000,-2187.5000000,13.8000002,134.9998779,6,0,-1);
	CreateVehicle(431,2736.0000000,-2187.5000000,13.8000002,134.9998779,6,0,-1);
	CreateVehicle(431,2729.0000000,-2187.5000000,13.8000002,134.9998779,6,0,-1);
	CreateVehicle(431,2722.0000000,-2187.5000000,13.8000002,134.9998779,6,0,-1);
	CreateVehicle(431,2715.0000000,-2187.5000000,13.8000002,134.9998779,6,0,-1);
	CreateVehicle(431,2708.0000000,-2187.5000000,13.8000002,134.9998779,6,0,-1);
	CreateVehicle(431,2701.0000000,-2187.5000000,13.8000002,134.9998779,6,0,-1);
	CreateVehicle(431,2694.0000000,-2187.5000000,13.8000002,134.9998779,6,0,-1);
	CreateVehicle(431,2687.0000000,-2187.5000000,13.8000002,134.9998779,6,0,-1);
	CreateVehicle(431,2680.0000000,-2187.5000000,13.8000002,134.9999390,6,0,-1);
	CreateVehicle(431,2673.0000000,-2187.5000000,13.8000002,134.9998779,6,0,-1);
	CreateVehicle(431,2666.0000000,-2187.5000000,13.8000002,134.9998779,6,0,-1);
	CreateVehicle(431,2659.0000000,-2187.5000000,13.8000002,134.9999390,6,0,-1);
	CreateVehicle(514,1133.4000244,1896.5000000,11.2775936,270.0000000,3,3,-1); //Tanker
	CreateVehicle(514,1133.4000244,1904.0000000,11.2775936,270.0000000,3,3,-1); //Tanker
	CreateVehicle(514,1133.4000244,1911.4000244,11.2775936,270.0000000,3,3,-1); //Tanker
	CreateVehicle(514,1133.4000244,1920.1999512,11.2775936,270.0000000,3,3,-1); //Tanker
	CreateVehicle(514,1133.4000244,1926.1999512,11.2775936,270.0000000,3,3,-1); //Tanker
	CreateVehicle(520,1133.4000244,1935.1999512,11.2775936,270.0000000,3,3,-1); //Tanker
	CreateVehicle(515,1171.1999512,1970.0000000,12.2224064,90.0000000,3,3,-1); //Roadtrain
	CreateVehicle(515,1171.1999512,1965.0000000,12.2224064,90.0000000,3,3,-1); //Roadtrain
	CreateVehicle(515,1171.1999512,1960.0000000,12.2224064,90.0000000,3,3,-1); //Roadtrain
	CreateVehicle(515,1171.1999512,1955.0000000,12.2224064,90.0000000,3,3,-1); //Roadtrain
	CreateVehicle(515,1171.1999512,1950.0000000,12.2224064,90.0000000,3,3,-1); //Roadtrain
	CreateVehicle(515,1171.1999512,1945.0000000,12.2224064,90.0000000,3,3,-1); //Roadtrain
	CreateVehicle(515,1171.1999512,1940.0000000,12.2224064,90.0000000,3,3,-1); //Roadtrain
	CreateVehicle(515,1171.1999512,1935.0000000,12.2224064,90.0000000,3,3,-1); //Roadtrain
	CreateVehicle(515,1171.1999512,1930.0000000,12.2224064,90.0000000,3,3,-1); //Roadtrain
	CreateVehicle(515,1171.1999512,1925.0000000,12.2224064,90.0000000,3,3,-1); //Roadtrain
	CreateVehicle(403,1136.1999512,1877.1999512,11.5000000,66.0000000,3,3,-1); //Linerunner
	CreateVehicle(403,1134.3000488,1872.9000244,11.5000000,66.0000000,3,3,-1); //Linerunner
	CreateVehicle(403,1132.4000244,1868.5999756,11.5000000,66.0000000,3,3,-1); //Linerunner
	CreateVehicle(403,1130.5999756,1864.5999756,11.3999996,66.0000000,3,3,-1); //Linerunner
	CreateVehicle(403,1128.8000488,1860.5999756,11.3000002,66.0000000,3,3,-1); //Linerunner
	CreateVehicle(403,1127.0999756,1856.6999512,11.3999996,66.0000000,3,3,-1); //Linerunner
	CreateVehicle(514,1115.0000000,1849.0000000,11.5000000,0.0000000,3,3,-1); //Tanker
	CreateVehicle(514,1110.0000000,1849.0000000,11.5000000,0.0000000,3,3,-1); //Tanker
	CreateVehicle(514,1105.0000000,1849.0000000,11.5000000,0.0000000,3,3,-1); //Tanker
	CreateVehicle(435,1086.0000000,1866.0000000,11.5000000,270.0000000,3,3,-1); //Trailer 1
	CreateVehicle(435,1086.0000000,1862.0000000,11.5000000,270.0000000,3,3,-1); //Trailer 1
	CreateVehicle(435,1086.0000000,1858.0000000,11.5000000,270.0000000,3,3,-1); //Trailer 1
	CreateVehicle(435,1086.0000000,1854.0000000,11.5000000,270.0000000,3,3,-1); //Trailer 1
	CreateVehicle(435,1086.0000000,1874.5000000,11.5000000,270.0000000,3,3,-1); //Trailer 1
	CreateVehicle(435,1086.0000000,1878.5000000,11.5000000,270.0000000,3,3,-1); //Trailer 1
	CreateVehicle(435,1086.0000000,1882.5000000,11.5000000,270.0000000,3,3,-1); //Trailer 1
	CreateVehicle(435,1086.0000000,1886.5000000,11.5000000,270.0000000,3,3,-1); //Trailer 1
	CreateVehicle(435,1086.0000000,1890.5000000,11.5000000,270.0000000,3,3,-1); //Trailer 1
	CreateVehicle(435,1086.0000000,1894.0999756,11.5000000,270.0000000,3,3,-1); //Trailer 1
	CreateVehicle(584,1091.4000244,1916.1999512,12.0000000,0.0000000,3,3,-1); //Trailer 3
	CreateVehicle(584,1082.6999512,1916.1999512,12.0000000,0.0000000,3,3,-1); //Trailer 3
	CreateVehicle(584,1076.6999512,1916.1999512,12.0000000,0.0000000,3,3,-1); //Trailer 3
	CreateVehicle(584,1067.9000244,1916.1999512,12.0000000,0.0000000,3,3,-1); //Trailer 3
	CreateVehicle(584,1060.4000244,1916.1999512,12.0000000,0.0000000,3,3,-1); //Trailer 3
	CreateVehicle(584,1052.9000244,1916.1999512,12.0000000,0.0000000,3,3,-1); //Trailer 3
	CreateVehicle(584,1052.5999756,1940.1999512,12.0000000,270.0000000,3,3,-1); //Trailer 3
	CreateVehicle(584,1052.5999756,1935.4000244,12.0000000,270.0000000,3,3,-1); //Trailer 3
	CreateVehicle(450,1108.6999512,1896.5000000,11.5000000,90.0000000,3,3,-1); //Trailer 2
	CreateVehicle(450,1108.6999512,1904.0000000,11.5000000,90.0000000,3,3,-1); //Trailer 2
	CreateVehicle(450,1108.6999512,1911.4000244,11.5000000,90.0000000,3,3,-1); //Trailer 2
	CreateVehicle(450,1108.6999512,1920.1999512,11.5000000,90.0000000,3,3,-1); //Trailer 2
	CreateVehicle(450,1108.6999512,1926.1999512,11.5000000,90.0000000,3,3,-1); //Trailer 2
	CreateVehicle(450,1108.6999512,1934.9000244,11.5000000,90.0000000,3,3,-1); //Trailer 2
	CreateVehicle(450,1108.6999512,1939.9000244,11.5000000,90.0000000,3,3,-1); //Trailer 2
	CreateVehicle(435,2818.0000000,897.4000244,10.8999996,0.0000000,-1,-1,-1); //Trailer 1
	CreateVehicle(435,2827.3000488,897.4000244,10.8999996,0.0000000,-1,-1,-1); //Trailer 1
	CreateVehicle(435,2822.6999512,897.4000244,11.3999996,0.0000000,-1,-1,-1); //Trailer 1
	CreateVehicle(435,2832.0000000,897.4000244,11.3999996,0.0000000,-1,-1,-1); //Trailer 1
	CreateVehicle(450,2836.5000000,897.4000244,11.3999996,0.0000000,-1,-1,-1); //Trailer 2
	CreateVehicle(450,2841.0000000,897.4000244,11.3999996,0.0000000,-1,-1,-1); //Trailer 2
	CreateVehicle(450,2845.5000000,897.4000244,11.3999996,0.0000000,-1,-1,-1); //Trailer 2
	CreateVehicle(450,2850.0000000,897.4000244,11.3999996,0.0000000,-1,-1,-1); //Trailer 2
	CreateVehicle(584,2855.1000977,897.4000244,11.5000000,0.0000000,-1,-1,-1); //Trailer 3
	CreateVehicle(584,2860.6999512,897.4000244,11.8999996,0.0000000,-1,-1,-1); //Trailer 3
	CreateVehicle(584,2865.8000488,897.4000244,11.8999996,0.0000000,-1,-1,-1); //Trailer 3
	CreateVehicle(584,2871.3999023,897.4000244,11.8999996,0.0000000,-1,-1,-1); //Trailer 3
	CreateVehicle(515,2885.0000000,910.0000000,11.8999996,90.0000000,-1,-1,-1); //Roadtrain
	CreateVehicle(515,2885.0000000,915.0000000,11.8999996,90.0000000,-1,-1,-1); //Roadtrain
	CreateVehicle(515,2885.0000000,920.0000000,11.8999996,90.0000000,-1,-1,-1); //Roadtrain
	CreateVehicle(515,2885.0000000,925.0000000,11.8999996,90.0000000,-1,-1,-1); //Roadtrain
	CreateVehicle(514,2885.0000000,930.0000000,11.3999996,90.0000000,-1,-1,-1); //Tanker
	CreateVehicle(514,2885.0000000,935.0000000,11.3999996,90.0000000,-1,-1,-1); //Tanker
	CreateVehicle(514,2885.0000000,940.0000000,11.3999996,90.0000000,-1,-1,-1); //Tanker
	CreateVehicle(514,2885.0000000,945.0000000,11.3999996,90.0000000,-1,-1,-1); //Tanker
	CreateVehicle(403,2885.0000000,950.0000000,11.5000000,90.0000000,-1,-1,-1); //Linerunner
	CreateVehicle(403,2885.0000000,955.0000000,11.6000004,90.0000000,-1,-1,-1); //Linerunner
	CreateVehicle(403,2885.0000000,960.0000000,11.6000004,90.0000000,-1,-1,-1); //Linerunner
	CreateVehicle(403,2885.0000000,965.0000000,11.6000004,90.0000000,-1,-1,-1); //Linerunner
	CreateVehicle(440,2801.3000488,928.2000122,11.0000000,180.0000000,-1,-1,-1); //Rumpo
	CreateVehicle(440,2804.8000488,928.2000122,11.0000000,180.0000000,-1,-1,-1); //Rumpo
	CreateVehicle(440,2808.0000000,928.2000122,11.0000000,180.0000000,-1,-1,-1); //Rumpo
	CreateVehicle(440,2811.1999512,928.2000122,11.0000000,180.0000000,-1,-1,-1); //Rumpo
	CreateVehicle(482,2833.6000977,928.2000122,11.0000000,180.0000000,-1,-1,-1); //Burrito
	CreateVehicle(482,2830.3999023,928.2000122,11.0000000,180.0000000,-1,-1,-1); //Burrito
	CreateVehicle(482,2827.1999512,928.2000122,11.0000000,180.0000000,-1,-1,-1); //Burrito
	CreateVehicle(482,2824.0000000,928.2000122,11.0000000,180.0000000,-1,-1,-1); //Burrito
	CreateVehicle(482,2820.8000488,928.2000122,11.0000000,180.0000000,-1,-1,-1); //Burrito
	CreateVehicle(482,2817.6999512,928.2000122,11.0000000,180.0000000,-1,-1,-1); //Burrito
	CreateVehicle(440,2814.3000488,928.2000122,11.0000000,180.0000000,-1,-1,-1); //Rumpo
	CreateVehicle(456,2807.3000488,965.7999878,11.0000000,180.0000000,-1,-1,-1); //Yankee
	CreateVehicle(456,2812.1999512,965.7999878,11.0000000,180.0000000,-1,-1,-1); //Yankee
	CreateVehicle(456,2817.3000488,965.7999878,11.0000000,180.0000000,-1,-1,-1); //Yankee
	CreateVehicle(456,2822.1999512,965.7999878,11.0000000,180.0000000,-1,-1,-1); //Yankee
	CreateVehicle(456,2827.3000488,965.7999878,11.0000000,180.0000000,-1,-1,-1); //Yankee
	CreateVehicle(414,2832.3000488,965.7999878,10.8999996,180.0000000,-1,-1,-1); //Mule
	CreateVehicle(414,2837.1999512,965.7999878,10.8999996,180.0000000,-1,-1,-1); //Mule
	CreateVehicle(414,2842.5000000,965.7999878,10.8999996,180.0000000,-1,-1,-1); //Mule
	CreateVehicle(414,2852.6000977,965.9000244,10.8999996,180.0000000,-1,-1,-1); //Mule
	CreateVehicle(414,2847.5000000,965.7999878,10.8999996,180.0000000,-1,-1,-1); //Mule
	CreateVehicle(523,1602.0999756,-1712.5000000,5.5999999,50.0000000,79,1,-1); //HPV1000
	CreateVehicle(523,1600.4000244,-1713.0000000,5.5999999,50.0000000,79,1,-1); //HPV1000
	CreateVehicle(523,1598.5000000,-1713.1999512,5.5999999,50.0000000,79,1,-1); //HPV1000
	CreateVehicle(490,1595.5000000,-1711.0999756,6.1999998,0.0000000,79,1,-1); //FBI Rancher
	CreateVehicle(490,1591.5000000,-1711.0999756,6.1999998,0.0000000,79,1,-1); //FBI Rancher
	CreateVehicle(490,1587.5000000,-1711.0999756,6.1999998,0.0000000,79,1,-1); //FBI Rancher
	CreateVehicle(490,1583.5000000,-1711.0999756,6.1999998,0.0000000,79,1,-1); //FBI Rancher
	CreateVehicle(490,1578.5999756,-1711.0999756,6.1999998,0.0000000,79,1,-1); //FBI Rancher
	CreateVehicle(490,1574.5000000,-1711.0999756,6.1999998,0.0000000,79,1,-1); //FBI Rancher
	CreateVehicle(490,1570.4000244,-1711.0999756,6.1999998,0.0000000,79,1,-1); //FBI Rancher
	CreateVehicle(490,1566.5000000,-1711.0999756,6.1999998,0.0000000,79,1,-1); //FBI Rancher
	CreateVehicle(490,1563.1999512,-1711.0999756,6.1999998,0.0000000,79,1,-1); //FBI Rancher
	CreateVehicle(490,1559.0000000,-1711.0999756,6.1999998,0.0000000,79,1,-1); //FBI Rancher
	
	AddPlayerClass(133, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Caminhoneiro   1
	AddPlayerClass(234, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Caminhoneiro   2
	AddPlayerClass(202, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Caminhoneiro   3
	AddPlayerClass(201, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Caminhoneiro   4
	AddPlayerClass(161, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Caminhoneiro   5
	AddPlayerClass(44, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0);  //Caminhoneiro   6
	AddPlayerClass(261, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Caminhoneiro   7
	AddPlayerClass(258, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Caminhoneiro   8
	AddPlayerClass(206, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Caminhoneiro   9
	AddPlayerClass(34, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0);  //Caminhoneiro   10
	AddPlayerClass(198, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Caminhoneiro   11
	AddPlayerClass(236, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Caminhoneiro   12
	AddPlayerClass(280, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Polícial       13
	AddPlayerClass(285, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Polícial       14
	AddPlayerClass(283, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Polícial       15
	AddPlayerClass(286, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Polícial       16
	AddPlayerClass(288, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Polícial       17
	AddPlayerClass(8, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0);   //Mecanico       18
    AddPlayerClass(42, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0);  //Mecanico       19
    AddPlayerClass(50, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0);  //Mecanico       20
    AddPlayerClass(255, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0);  //Motorista Bus 21
    AddPlayerClass(253, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0);  //Motorista Bus 22
    AddPlayerClass(120, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Máfia          23
    AddPlayerClass(98, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0);  //Máfia          24
    AddPlayerClass(117, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Máfia          25
    AddPlayerClass(111, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0); //Máfia          26
    

	LogoC = TextDrawCreate(270.5,405.0, "Carga");
	TextDrawFont(LogoC, 1);
	TextDrawColor(LogoC, 0x66FF00FF);
	TextDrawLetterSize(LogoC, 0.4, 1.3);
 	TextDrawSetOutline(LogoC, 1);
  	TextDrawSetProportional(LogoC, 1);
  	TextDrawAlignment(LogoC, 2);
  	TextDrawBackgroundColor(LogoC, 0x000000FF);
  	TextDrawSetShadow(LogoC, 1);


    LogoP = TextDrawCreate(316.5,405.0, "Pesada");
	TextDrawFont(LogoP, 1);
	TextDrawColor(LogoP, 0xFFFF00FF);
	TextDrawLetterSize(LogoP, 0.4, 1.3);
 	TextDrawSetOutline(LogoP, 1);
  	TextDrawSetProportional(LogoP, 1);
  	TextDrawAlignment(LogoP, 2);
  	TextDrawBackgroundColor(LogoP, 0x000000FF);
  	TextDrawSetShadow(LogoP, 1);

	LogoB = TextDrawCreate(360.5,405.0, "Brasil");
	TextDrawFont(LogoB, 1);
	TextDrawColor(LogoB, 0x66FFFF);
	TextDrawLetterSize(LogoB, 0.4, 1.3);
 	TextDrawSetOutline(LogoB, 1);
  	TextDrawSetProportional(LogoB, 1);
  	TextDrawAlignment(LogoB, 2);
  	TextDrawBackgroundColor(LogoB, 0x000000FF);
  	TextDrawSetShadow(LogoB, 1);
  	
  	SiteCPB = TextDrawCreate(316.5,420.0, "www.cargapesadabrasil.com.br");
	TextDrawFont(SiteCPB, 1);
	TextDrawColor(SiteCPB, 0xFFFFFFFF);
	TextDrawLetterSize(SiteCPB, 0.3, 1.0);
 	TextDrawSetOutline(SiteCPB, 1);
  	TextDrawSetProportional(SiteCPB, 1);
  	TextDrawAlignment(SiteCPB, 2);
  	TextDrawBackgroundColor(SiteCPB, 0x000000FF);
  	TextDrawSetShadow(SiteCPB, 1);
  	
  	gettime(ClockTime[tHour], ClockTime[tMinute], ClockTime[tSecond]);
	getdate(ClockTime[dYear], ClockTime[dMonth], ClockTime[dDay]);

	new str[128];
	format(str,128, "~n~%02d:%02d:%02d - %02d/%02d", ClockTime[tHour], ClockTime[tMinute], ClockTime[tSecond], ClockTime[dDay], ClockTime[dMonth]);
    DataeHora = TextDrawCreate(316.5, 433.5, str);
	TextDrawFont(DataeHora, 1);
	TextDrawColor(DataeHora, 0xFFFFFFFF);
	TextDrawLetterSize(DataeHora, 0.3, 0.8);
 	TextDrawSetOutline(DataeHora, 1);
  	TextDrawSetProportional(DataeHora, 1);
  	TextDrawAlignment(DataeHora, 2);
  	TextDrawBackgroundColor(DataeHora, 0x000000FF);
  	TextDrawSetShadow(DataeHora, 1);
  	
  	Carregando = TextDrawCreate(320.5, 200.5, "Aguarde, carregando gamemode!");
	TextDrawFont(Carregando, 1);
	TextDrawColor(Carregando, 0xFFFFFFFF);
	TextDrawLetterSize(Carregando, 1.0, 4.0);
 	TextDrawSetOutline(Carregando, 1);
  	TextDrawSetProportional(Carregando, 1);
  	TextDrawAlignment(Carregando, 2);
  	TextDrawBackgroundColor(Carregando, 0x000000FF);
  	TextDrawSetShadow(Carregando, 1);
  	
  	Carregando1 = TextDrawCreate(195.0,250.0, "Carga");
	TextDrawFont(Carregando1, 2);
	TextDrawColor(Carregando1, 0x66FF00FF);
	TextDrawLetterSize(Carregando1, 0.8, 3.0);
 	TextDrawSetOutline(Carregando1, 1);
  	TextDrawSetProportional(Carregando1, 1);
  	TextDrawAlignment(Carregando1, 2);
  	TextDrawBackgroundColor(Carregando1, 0x000000FF);
  	TextDrawSetShadow(Carregando1, 1);

    Carregando2 = TextDrawCreate(320.5,250.0, "Pesada");
	TextDrawFont(Carregando2, 2);
	TextDrawColor(Carregando2, 0xFFFF00FF);
	TextDrawLetterSize(Carregando2, 0.8, 3.0);
 	TextDrawSetOutline(Carregando2, 1);
  	TextDrawSetProportional(Carregando2, 1);
  	TextDrawAlignment(Carregando2, 2);
  	TextDrawBackgroundColor(Carregando2, 0x000000FF);
  	TextDrawSetShadow(Carregando2, 1);

	Carregando3 = TextDrawCreate(449.0,250.0, "Brasil");
	TextDrawFont(Carregando3, 2);
	TextDrawColor(Carregando3, 0x66FFFF);
	TextDrawLetterSize(Carregando3, 0.8, 3.0);
 	TextDrawSetOutline(Carregando3, 1);
  	TextDrawSetProportional(Carregando3, 1);
  	TextDrawAlignment(Carregando3, 2);
  	TextDrawBackgroundColor(Carregando3, 0x000000FF);
  	TextDrawSetShadow(Carregando3, 1);
  	
  	Velocimetro = TextDrawCreate(316.5,420.0, " ");
	TextDrawFont(Velocimetro, 1);
	TextDrawColor(Velocimetro, 0xFFFFFFFF);
	TextDrawLetterSize(Velocimetro, 0.3, 1.0);
 	TextDrawSetOutline(Velocimetro, 1);
  	TextDrawSetProportional(Velocimetro, 1);
  	TextDrawAlignment(Velocimetro, 2);
  	TextDrawBackgroundColor(Velocimetro, 0x000000FF);
  	TextDrawSetShadow(Velocimetro, 1);
  	
  	DinheiroR = TextDrawCreate(486.500,77.5000,"~g~R");
	TextDrawColor(DinheiroR, 0xffffffff);
	TextDrawLetterSize(DinheiroR, 0.575, 2.1);
	TextDrawFont(DinheiroR, 3);
	TextDrawBackgroundColor(DinheiroR, 0x00000AA);
	TextDrawSetOutline(DinheiroR, 2);
  	
  	SetWorldTime(ClockTime[tHour]+3);
  	SetTimer("SyncClock", 1000,true);
  	SetTimer("Velocidade", 500,true);
  	SetTimer("ChecarVidadoCarro", 1000,true);
	SetTimer("Mensagens", 300000,true);
	return 1;
}

public OnGameModeExit()
{
    for(new i = 0; i <= MAX_PLAYERS; i++)
	{
	    if(IsPlayerConnected(i))
	    {
	    	new
        		query[150];
    		mysql_format(mysql, query, sizeof(query), "UPDATE `contas` SET `Dinheiro` = %d, `Pontos` = %d, `AdminLevel` = %d, `MsgBoasVindas` = %d WHERE `ID` = %d", PlayerInfo[i][pDinheiro], PlayerInfo[i][pPontos], PlayerInfo[i][pAdmin], PlayerInfo[i][MsgBoasVindas], PlayerInfo[i][pID]);
   			mysql_tquery(mysql, query, "", "");
		}
  	}
    return printf("Contas salvas com sucesso!");
}

public SyncClock(playerid)
{
	new str[128];
	gettime(ClockTime[tHour], ClockTime[tMinute], ClockTime[tSecond]);
	getdate(ClockTime[dYear], ClockTime[dMonth], ClockTime[dDay]);
	format(str,128, "%02d:%02d:%02d - %02d/%02d/%04d", ClockTime[tHour], ClockTime[tMinute], ClockTime[tSecond], ClockTime[dDay], ClockTime[dMonth], ClockTime[dYear]);
	TextDrawSetString(DataeHora, str);
}


public OnPlayerConnect(playerid)
{
    TogglePlayerSpectating(playerid, true);
	SetPlayerColor(playerid, 0xFFFFFFFF);
 	SendDeathMessage(INVALID_PLAYER_ID, playerid, 200);
 	TogglePlayerClock(playerid, 0);
    TextDrawShowForPlayer(playerid, Carregando);
    TextDrawShowForPlayer(playerid, Carregando1);
    TextDrawShowForPlayer(playerid, Carregando2);
    TextDrawShowForPlayer(playerid, Carregando3);
	SetPlayerColor(playerid, 0xAFAFAFFF);
    CreateObject(3637,2635.1999512,-2138.6000977,20.6000004,0.0000000,0.0000000,90.0000000);
	CreateObject(3627,2232.5000000,-2243.0000000,16.0000000,0.0000000,0.0000000,135.0000000);
	CreateObject(3627,2203.3701172,-2272.0000000,16.0000000,0.0000000,0.0000000,135.0000000);
	Create3DTextLabel("{FFFFFF}Terminal Porto\nLos Santos", 0x0000000, 2619.5,-2227.3,19.6, 50.0, 0, 0);
	Create3DTextLabel("{FFFFFF}Depósito Santa Fé\nLas Venturas", 0x0000000, 1069.3, 1943.5, 17.3, 50.0, 0, 0);
	Create3DTextLabel("{FFFFFF}Depósito Garagem\nLas Venturas", 0x0000000, 2776.9, 913.4, 17.8, 50.0, 0, 0);
	Create3DTextLabel("{FFFFFF}Editar 1\nLos Santos", 0x0000000, 2227.8, -2210.8, 21.4, 50.0, 0, 0);
	Create3DTextLabel("{FFFFFF}Editar 2\nLos Santos", 0x0000000, 2424.1, -2082.5, 20.2, 50.0, 0, 0);
	CreateObject(7657,1607.4000244,2283.1999512,11.5000000,0.0000000,0.0000000,0.0000000);
	CreateObject(7657,1577.4000244,2333.1000977,11.5000000,0.0000000,0.0000000,270.0000000);
	CreateObject(7520,2478.6000977,-2080.6999512,12.5000000,0.0000000,0.0000000,0.0000000);
	CreateObject(4022,2666.3999023,-2128.8999023,15.6000004,0.0000000,0.0000000,180.0000000);
	CreateObject(970,2651.3000488,-2132.3999023,13.1000004,0.0000000,0.0000000,90.0000000);
	CreateObject(970,2651.3000488,-2128.3000488,13.1000004,0.0000000,0.0000000,90.0000000);
	CreateObject(970,2651.3000488,-2124.1999512,13.1000004,0.0000000,0.0000000,90.0000000);
	CreateObject(970,2651.3000488,-2120.1000977,13.1000004,0.0000000,0.0000000,90.0000000);
	CreateObject(970,2651.1999512,-2113.8999023,13.1000004,0.0000000,0.0000000,90.0000000);
	CreateObject(970,2651.1999512,-2109.8000488,13.1000004,0.0000000,0.0000000,90.0000000);
	CreateObject(970,2651.1999512,-2105.6999512,13.1000004,0.0000000,0.0000000,90.0000000);
	CreateObject(970,2653.2800293,-2103.6699219,13.1000004,0.0000000,0.0000000,0.0000000);
	CreateObject(970,2657.3999023,-2103.6699219,13.1000004,0.0000000,0.0000000,0.0000000);
	CreateObject(970,2661.5000000,-2103.6699219,13.1000004,0.0000000,0.0000000,0.0000000);
	CreateObject(970,2665.6000977,-2103.6699219,13.1000004,0.0000000,0.0000000,0.0000000);
	CreateObject(970,2669.6999512,-2103.6699219,13.1000004,0.0000000,0.0000000,0.0000000);
	CreateObject(970,2673.8000488,-2103.6699219,13.1000004,0.0000000,0.0000000,0.0000000);
	CreateObject(970,2677.8999023,-2103.6699219,13.1000004,0.0000000,0.0000000,0.0000000);
	CreateObject(970,2682.0000000,-2103.6699219,13.1000004,0.0000000,0.0000000,0.0000000);
	CreateObject(970,2684.1000977,-2105.6999512,13.1000004,0.0000000,0.0000000,270.0000000);
	CreateObject(970,2684.1000977,-2109.8000488,13.1000004,0.0000000,0.0000000,270.0000000);
	CreateObject(970,2684.1000977,-2113.8999023,13.1000004,0.0000000,0.0000000,270.0000000);
	CreateObject(970,2684.1000977,-2118.0000000,13.1000004,0.0000000,0.0000000,270.0000000);
	CreateObject(970,2684.1000977,-2122.1000977,13.1000004,0.0000000,0.0000000,270.0000000);
	CreateObject(970,2684.1000977,-2126.1999512,13.1000004,0.0000000,0.0000000,270.0000000);
	CreateObject(970,2684.1000977,-2130.3000488,13.1000004,0.0000000,0.0000000,270.0000000);
	CreateObject(970,2684.1000977,-2134.3999023,13.1000004,0.0000000,0.0000000,270.0000000);
	CreateObject(16151,2665.1999512,-2104.8000488,12.8999996,0.0000000,0.0000000,90.0000000);
	CreateObject(1668,2661.8999023,-2105.6000977,13.6999998,0.0000000,0.0000000,0.0000000);
	CreateObject(1544,2663.6999512,-2104.1000977,13.5000000,0.0000000,0.0000000,0.0000000);
	CreateObject(1950,2662.5000000,-2105.8999023,13.6999998,0.0000000,0.0000000,0.0000000);
	CreateObject(1509,2662.8000488,-2105.8000488,13.6999998,0.0000000,0.0000000,0.0000000);
	CreateObject(1546,2663.8999023,-2106.0000000,13.6000004,0.0000000,0.0000000,0.0000000);
	CreateObject(1541,2667.1999512,-2105.3999023,13.8000002,0.0000000,0.0000000,0.0000000);
	CreateObject(1510,2664.6999512,-2105.6999512,13.5400000,0.0000000,0.0000000,0.0000000);
	CreateObject(1545,2666.1999512,-2105.3999023,13.8999996,0.0000000,0.0000000,0.0000000);
	CreateObject(1667,2662.3000488,-2105.6999512,13.6149998,0.0000000,0.0000000,0.0000000);
	CreateObject(1666,2664.1000977,-2106.0000000,13.6000004,0.0000000,0.0000000,0.0000000);
	CreateObject(643,2658.0000000,-2110.6000977,13.0000000,0.0000000,0.0000000,0.0000000);
	CreateObject(1670,2658.0000000,-2110.6000977,13.3999996,0.0000000,0.0000000,0.0000000);
	CreateObject(1679,2656.3000488,-2116.1999512,13.0000000,0.0000000,0.0000000,17.0000000);
	CreateObject(643,2658.8999023,-2121.1000977,13.0000000,0.0000000,0.0000000,65.0000000);
	CreateObject(643,2666.8999023,-2110.5000000,13.0000000,0.0000000,0.0000000,0.0000000);
	CreateObject(1679,2667.1000977,-2116.0000000,13.0000000,0.0000000,0.0000000,0.0000000);
	CreateObject(643,2672.6000977,-2120.8000488,13.0000000,0.0000000,0.0000000,0.0000000);
	CreateObject(643,2679.3999023,-2110.1000977,13.0000000,0.0000000,0.0000000,0.0000000);
	CreateObject(1679,2678.1999512,-2116.1999512,13.0000000,0.0000000,0.0000000,0.0000000);
	CreateObject(643,2681.0000000,-2123.6000977,13.0000000,0.0000000,0.0000000,300.0000000);
	CreateObject(3089,2664.8000488,-2124.0000000,13.8999996,0.0000000,0.0000000,0.0000000);
	CreateObject(3089,2664.8000488,-2124.0000000,13.8999996,0.0000000,0.0000000,180.0000000);
	CreateObject(1517,2681.1999512,-2123.6000977,13.6000004,0.0000000,0.0000000,0.0000000);
	CreateObject(2800,2656.1999512,-2116.8000488,13.3999996,0.0000000,0.0000000,0.0000000);
	CreateObject(12853,2449.3999023,-2071.0000000,14.6000004,0.0000000,0.0000000,90.0000000);
	CreateObject(3578,2520.1000977,-2106.5000000,13.3000002,0.0000000,0.0000000,90.0000000);
	CreateObject(3578,2520.1000977,-2116.8000488,13.3000002,0.0000000,0.0000000,90.1999817);
	CreateObject(3465,2445.1101074,-2082.1999512,13.9399996,0.0000000,0.0000000,270.0000000);
	CreateObject(3465,2444.1000977,-2082.1999512,13.9399996,0.0000000,0.0000000,270.0000000);
	CreateObject(3465,2453.4499512,-2082.1999512,13.8999996,0.0000000,0.0000000,90.0000000);
	CreateObject(3465,2454.5000000,-2082.2099609,13.8999996,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,1176.5999756,2036.5999756,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (1)
	CreateObject(3475,1176.5999756,2030.8000488,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (2)
	CreateObject(3475,1176.5999756,2024.8000488,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (3)
	CreateObject(3475,1176.5999756,2018.8000488,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (4)
	CreateObject(3475,1176.5999756,2012.8000488,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (5)
	CreateObject(3475,1176.5999756,2006.8000488,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (6)
	CreateObject(3475,1176.5999756,2000.8000488,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (7)
	CreateObject(3475,1176.5999756,1994.8000488,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (8)
	CreateObject(3475,1176.5999756,1988.9000244,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (9)
	CreateObject(3475,1176.5999756,1982.9000244,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (10)
	CreateObject(3475,1176.5999756,1977.0000000,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (11)
	CreateObject(3475,1176.5999756,1971.0000000,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (12)
	CreateObject(3475,1176.5999756,1965.0000000,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (13)
	CreateObject(3475,1176.5999756,1959.0000000,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (14)
	CreateObject(3475,1176.5999756,1953.0000000,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (15)
	CreateObject(3475,1176.5999756,1947.0000000,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (16)
	CreateObject(3475,1176.5999756,1941.0000000,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (17)
	CreateObject(3475,1176.5999756,1935.0000000,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (18)
	CreateObject(3475,1176.5999756,1929.0000000,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (19)
	CreateObject(3475,1176.5999756,1925.9990234,10.2399998,0.0000000,0.0000000,180.0000000); //object(vgsn_fncelec_pst) (20)
	CreateObject(3475,1175.1999512,1920.5000000,10.2399998,0.0000000,0.0000000,152.0000000); //object(vgsn_fncelec_pst) (21)
	CreateObject(3475,1172.4000244,1915.1999512,10.2399998,0.0000000,0.0000000,152.0000000); //object(vgsn_fncelec_pst) (22)
	CreateObject(3475,1169.5999756,1910.0000000,10.2399998,0.0000000,0.0000000,152.0000000); //object(vgsn_fncelec_pst) (23)
	CreateObject(3475,1168.1999512,1907.3699951,10.2399998,0.0000000,0.0000000,151.0000000); //object(vgsn_fncelec_pst) (24)
	CreateObject(3475,1164.0000000,1905.1300049,10.2399998,0.0000000,0.0000000,85.0000000); //object(vgsn_fncelec_pst) (25)
	CreateObject(3475,1158.0999756,1905.6999512,10.2399998,0.0000000,0.0000000,85.0000000); //object(vgsn_fncelec_pst) (26)
	CreateObject(3475,1153.6999512,1903.0999756,10.2399998,0.0000000,0.0000000,156.0000000); //object(vgsn_fncelec_pst) (27)
	CreateObject(3475,1151.1999512,1897.6999512,10.2399998,0.0000000,0.0000000,156.0000000); //object(vgsn_fncelec_pst) (28)
	CreateObject(3475,1148.8000488,1892.3000488,10.2399998,0.0000000,0.0000000,156.0000000); //object(vgsn_fncelec_pst) (29)
	CreateObject(3475,1146.4000244,1886.8000488,10.2399998,0.0000000,0.0000000,156.0000000); //object(vgsn_fncelec_pst) (30)
	CreateObject(3475,1143.9000244,1881.4000244,10.2399998,0.0000000,0.0000000,155.0000000); //object(vgsn_fncelec_pst) (31)
	CreateObject(3475,1141.4000244,1876.0000000,10.2399998,0.0000000,0.0000000,155.0000000); //object(vgsn_fncelec_pst) (32)
	CreateObject(3475,1138.9000244,1870.5999756,10.2399998,0.0000000,0.0000000,155.0000000); //object(vgsn_fncelec_pst) (33)
	CreateObject(3475,1136.4000244,1865.1999512,10.2399998,0.0000000,0.0000000,155.0000000); //object(vgsn_fncelec_pst) (34)
	CreateObject(3475,1133.9000244,1859.8000488,10.2399998,0.0000000,0.0000000,155.0000000); //object(vgsn_fncelec_pst) (35)
	CreateObject(3475,1131.4000244,1854.4000244,10.2399998,0.0000000,0.0000000,155.0000000); //object(vgsn_fncelec_pst) (36)
	CreateObject(3475,1129.4000244,1848.8000488,10.2399998,0.0000000,0.0000000,167.0000000); //object(vgsn_fncelec_pst) (37)
	CreateObject(3475,1128.5999756,1845.9000244,10.1999998,0.0000000,0.0000000,167.0000000); //object(vgsn_fncelec_pst) (38)
	CreateObject(7657,1147.4000244,2043.0000000,11.0000000,0.0000000,0.0000000,180.0000000); //object(plasticsgate1) (1)
	CreateObject(973,1113.5999756,1946.5999756,10.6999998,0.0000000,0.0000000,270.0000000); //object(sub_roadbarrier) (1)
	CreateObject(973,1113.5999756,1939.6999512,10.6999998,0.0000000,0.0000000,270.0000000); //object(sub_roadbarrier) (2)
	CreateObject(973,1113.5999756,1946.3000488,10.6999998,0.0000000,0.0000000,90.0000000); //object(sub_roadbarrier) (3)
	CreateObject(973,1113.5999756,1942.0000000,10.6999998,0.0000000,0.0000000,90.0000000); //object(sub_roadbarrier) (4)
	CreateObject(973,1122.5000000,1979.9000244,10.6999998,0.0000000,0.0000000,180.0000000); //object(sub_roadbarrier) (5)
	CreateObject(973,1122.0000000,1979.9000244,10.6999998,0.0000000,0.0000000,0.0000000);
	CreateObject(984,1081.9000244,1849.5999756,10.5000000,0.0000000,0.0000000,0.0000000); //object(fenceshit2) (1)
	CreateObject(984,1081.9000244,1862.4000244,10.5000000,0.0000000,0.0000000,0.0000000); //object(fenceshit2) (2)
	CreateObject(984,1081.9000244,1891.5999756,10.5000000,0.0000000,0.0000000,0.0000000); //object(fenceshit2) (4)
	CreateObject(984,1081.9000244,1878.8000488,10.5000000,0.0000000,0.0000000,0.0000000); //object(fenceshit2) (5)
	CreateObject(9583,1081.9000244,1870.5999756,-12.3999996,0.0000000,0.0000000,0.0000000); //object(freight_sfw15) (1)
	CreateObject(3749,2621.1999512,-2229.1999512,18.2000008,0.0000000,0.0000000,45.0000000); //object(clubgate01_lax) (1)
	CreateObject(978,2629.1999512,-2228.6000977,13.3999996,0.0000000,0.0000000,135.0000000); //object(sub_roadright) (1)
	CreateObject(4642,2619.8000488,-2237.6999512,14.1999998,0.0000000,0.0000000,315.0000000); //object(paypark_lan) (1)
	CreateObject(7371,2735.5000000,-2249.3000488,9.0000000,0.0000000,0.0000000,270.0000000); //object(vgsnelec_fence_02) (1)
	CreateObject(3475,2615.6999512,-2246.1999512,11.3669996,0.0000000,0.0000000,0.0000000); //object(vgsn_fncelec_pst) (39)
	CreateObject(3475,2615.8000488,-2240.3000488,11.3669996,0.0000000,0.0000000,0.0000000); //object(vgsn_fncelec_pst) (40)
	CreateObject(3475,2626.6000977,-2218.6000977,14.8999996,0.0000000,0.0000000,0.0000000); //object(vgsn_fncelec_pst) (41)
	CreateObject(3475,2626.6000977,-2212.6999512,14.8999996,0.0000000,0.0000000,0.0000000); //object(vgsn_fncelec_pst) (42)
	CreateObject(3475,2626.6000977,-2206.8000488,14.8999996,0.0000000,0.0000000,0.0000000); //object(vgsn_fncelec_pst) (43)
	CreateObject(3475,2626.6000977,-2200.8999023,14.8999996,0.0000000,0.0000000,0.0000000); //object(vgsn_fncelec_pst) (44)
	CreateObject(3475,2626.6000977,-2195.0000000,14.8999996,0.0000000,0.0000000,0.0000000); //object(vgsn_fncelec_pst) (45)
	CreateObject(3475,2626.6000977,-2189.0000000,14.8999996,0.0000000,0.0000000,0.0000000); //object(vgsn_fncelec_pst) (46)
	CreateObject(3475,2626.6000977,-2184.5000000,14.8999996,0.0000000,0.0000000,0.0000000); //object(vgsn_fncelec_pst) (47)
	CreateObject(3475,2750.6000977,-2249.0000000,11.3859997,0.0000000,0.0000000,90.0000000); //object(vgsn_fncelec_pst) (48)
	CreateObject(3475,2756.5000000,-2249.1000977,11.3859997,0.0000000,0.0000000,90.0000000); //object(vgsn_fncelec_pst) (49)
	CreateObject(3475,2761.1000977,-2249.1000977,11.3859997,0.0000000,0.0000000,90.0000000);
	CreateObject(983,1085.0000000,1868.6999512,10.5000000,0.0000000,0.0000000,90.0000000); //object(fenceshit3) (1)
	CreateObject(983,1085.0999756,1872.4000244,10.5000000,0.0000000,0.0000000,90.0000000); //object(fenceshit3) (2)
	CreateObject(6010,1070.6999512,1873.0000000,10.8999996,0.0000000,0.0000000,270.0000000); //object(lawnboigashot25) (1)
	CreateObject(643,1074.1999512,1888.8000488,10.3000002,0.0000000,0.0000000,0.0000000); //object(kb_chr_tbl_test) (1)
	CreateObject(643,1078.5999756,1879.6999512,10.3000002,0.0000000,0.0000000,90.0000000); //object(kb_chr_tbl_test) (2)
	CreateObject(1679,1066.5000000,1891.1999512,10.3000002,0.0000000,0.0000000,0.0000000); //object(chairsntableml) (1)
	CreateObject(1679,1068.1999512,1882.3000488,10.3000002,0.0000000,0.0000000,0.0000000); //object(chairsntableml) (2)
	CreateObject(1679,1053.3000488,1883.9000244,10.3000002,0.0000000,0.0000000,0.0000000); //object(chairsntableml) (3)
	CreateObject(3336,1063.4000244,1943.0999756,10.3000002,0.0000000,0.0000000,90.0000000); //object(cxrf_frway1sig) (1)
	CreateObject(3435,2227.3999023,-2210.3000488,17.6000004,0.0000000,0.0000000,135.0000000); //object(motel01sgn_lvs) (1)
	CreateObject(7246,2424.3999023,-2080.1999512,16.7000008,0.0000000,0.0000000,270.0000000);
	CreateObject(970,2799.8000488,890.7000122,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (4)
	CreateObject(970,2795.6999512,890.7000122,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (5)
	CreateObject(970,2791.6000977,890.7000122,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (6)
	CreateObject(970,2787.5000000,890.7000122,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (7)
	CreateObject(970,2779.2299805,890.7000122,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (8)
	CreateObject(970,2783.3999023,890.7000122,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (9)
	CreateObject(970,2803.8999023,890.7000122,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (10)
	CreateObject(12859,2798.1398926,843.2700195,9.8000002,0.0000000,0.0000000,90.0000000); //object(sw_cont03) (1)
	CreateObject(12913,2795.3999023,878.2999878,12.3999996,0.0000000,0.0000000,0.0000000); //object(sw_fueldrum03) (1)
	CreateObject(17019,2841.5000000,848.7000122,15.8000002,0.0000000,0.0000000,0.0000000); //object(cuntfrates1) (1)
	CreateObject(970,2893.0000000,890.7000122,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (11)
	CreateObject(970,2888.8999023,890.7000122,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (12)
	CreateObject(970,2884.6999512,890.7000122,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (13)
	CreateObject(2935,2893.3999023,885.7000122,11.3999996,0.0000000,0.0000000,0.0000000); //object(kmb_container_yel) (1)
	CreateObject(2935,2893.3999023,885.7000122,14.3000002,0.0000000,0.0000000,0.0000000); //object(kmb_container_yel) (2)
	CreateObject(2934,2887.6000977,885.7000122,11.1999998,0.0000000,0.0000000,0.0000000); //object(kmb_container_red) (1)
	CreateObject(2932,2887.6000977,885.7000122,14.1000004,0.0000000,0.0000000,0.0000000); //object(kmb_container_blue) (1)
	CreateObject(2912,2879.3999023,858.0999756,11.1999998,0.0000000,0.0000000,0.0000000); //object(temp_crate1) (1)
	CreateObject(1431,2873.8000488,857.9000244,10.3000002,0.0000000,0.0000000,0.0000000); //object(dyn_box_pile) (1)
	CreateObject(2567,2870.1999512,852.0000000,11.6999998,0.0000000,0.0000000,90.0000000); //object(ab_warehouseshelf) (1)
	CreateObject(2567,2870.1999512,846.7999878,11.6999998,0.0000000,0.0000000,90.0000000); //object(ab_warehouseshelf) (2)
	CreateObject(2669,2870.8000488,841.4000244,11.1000004,0.0000000,0.0000000,0.0000000); //object(cj_chris_crate) (1)
	CreateObject(3573,2887.1999512,837.4000244,12.6000004,0.0000000,0.0000000,0.0000000); //object(lasdkrtgrp1) (1)
	CreateObject(17019,2867.3999023,980.9000244,15.8999996,0.0000000,0.0000000,0.0000000); //object(cuntfrates1) (3)
	CreateObject(12930,2848.8000488,969.7999878,23.0000000,0.0000000,0.0000000,0.0000000); //object(sw_pipepile02) (1)
	CreateObject(12930,2851.3000488,969.7999878,23.0000000,0.0000000,0.0000000,0.0000000); //object(sw_pipepile02) (2)
	CreateObject(17020,2822.1999512,981.0999756,13.6999998,0.0000000,0.0000000,90.0000000); //object(cuntfrates02) (1)
	CreateObject(17020,2787.1999512,983.9000244,13.6999998,0.0000000,0.0000000,180.0000000); //object(cuntfrates02) (2)
	CreateObject(970,2803.0000000,971.2000122,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (14)
	CreateObject(970,2798.8999023,971.2000122,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (15)
	CreateObject(970,2798.8999023,971.2000122,11.3999996,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (16)
	CreateObject(970,2803.0000000,971.2000122,11.3999996,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (17)
	CreateObject(970,2798.8999023,971.2000122,12.5000000,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (18)
	CreateObject(970,2803.0000000,971.2000122,12.5000000,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (19)
	CreateObject(970,2779.1999512,923.4000244,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (1)
	CreateObject(970,2783.3000488,923.4000244,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (2)
	CreateObject(970,2793.6000977,923.4000244,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (3)
	CreateObject(970,2789.5000000,923.4000244,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (20)
	CreateObject(970,2795.6999512,923.4000244,10.3000002,0.0000000,0.0000000,0.0000000); //object(fencesmallb) (21)
	CreateObject(970,2797.8000488,925.4699707,10.3000002,0.0000000,0.0000000,90.0000000); //object(fencesmallb) (22)
	CreateObject(970,2797.8000488,929.5999756,10.3000002,0.0000000,0.0000000,90.0000000); //object(fencesmallb) (23)
	CreateObject(970,2797.8000488,933.7000122,10.3000002,0.0000000,0.0000000,90.0000000); //object(fencesmallb) (24)
	CreateObject(970,2797.8000488,937.7999878,10.3000002,0.0000000,0.0000000,90.0000000); //object(fencesmallb) (25)
	CreateObject(970,2797.8000488,941.9000244,10.3000002,0.0000000,0.0000000,90.0000000); //object(fencesmallb) (26)
	CreateObject(970,2797.8000488,946.0000000,10.3000002,0.0000000,0.0000000,90.0000000); //object(fencesmallb) (27)
	CreateObject(970,2797.8000488,950.0999756,10.3000002,0.0000000,0.0000000,90.0000000); //object(fencesmallb) (28)
	CreateObject(970,2797.8000488,954.2000122,10.3000002,0.0000000,0.0000000,90.0000000); //object(fencesmallb) (29)
	CreateObject(970,2797.8000488,958.2999878,10.3000002,0.0000000,0.0000000,90.0000000); //object(fencesmallb) (30)
	CreateObject(970,2797.8000488,962.4000244,10.3000002,0.0000000,0.0000000,90.0000000); //object(fencesmallb) (31)
	CreateObject(970,2797.8000488,966.5000000,10.3000002,0.0000000,0.0000000,90.0000000); //object(fencesmallb) (32)
	CreateObject(970,2797.8000488,969.0999756,10.3000002,0.0000000,0.0000000,90.0000000); //object(fencesmallb) (33)
	CreateObject(1673,2776.6000977,913.4000244,14.1999998,0.0000000,0.0000000,90.0000000); //object(roadsign) (1)
	CreateObject(1673,2777.5000000,913.2000122,14.1999998,0.0000000,0.0000000,270.0000000); //object(roadsign) (2)
	CreateObject(2790,2777.0000000,913.4500122,17.2999992,0.0000000,0.0000000,90.0000000); //object(cj_arrive_board) (1)
	CreateObject(2790,2777.1000977,913.4500122,17.2999992,0.0000000,0.0000000,270.0000000); //object(cj_arrive_board) (2)
	//=======================================================================================================================
	//-------------------------------------------------------------- LAS VENTURAS -------------------------------------------
	//=======================================================================================================================
	
	//--------------------------------------------------------- TERMINAL ONIBUS AVENIDA -------------------------------------
	CreateObject(3475,2000.1999512,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2006.1992188,2032.3994141,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2012.0000000,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2018.0000000,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2024.0000000,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2030.0000000,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2036.0000000,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2042.0000000,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2048.0000000,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2054.0000000,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2060.0000000,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2066.0000000,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2072.0000000,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2078.0000000,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2084.0000000,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2090.0000000,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2096.0000000,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2101.8999023,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2104.8999023,2032.4000244,12.1999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2107.5000000,2035.1999512,12.1999998,0.0000000,0.0000000,180.0000000);
	CreateObject(3475,2107.5000000,2041.0999756,12.1999998,0.0000000,0.0000000,180.0000000);
	CreateObject(3475,2107.5000000,2047.0000000,12.1999998,0.0000000,0.0000000,180.0000000);
	CreateObject(3475,2107.5000000,2053.0000000,12.1999998,0.0000000,0.0000000,180.0000000);
	CreateObject(3475,2107.5000000,2058.8999023,12.1999998,0.0000000,0.0000000,180.0000000);
	CreateObject(3475,2107.5000000,2100.1999512,12.1999998,0.0000000,0.0000000,180.0000000);
	CreateObject(3475,2107.5000000,2094.1999512,12.1999998,0.0000000,0.0000000,180.0000000);
	CreateObject(3475,2107.5000000,2088.1999512,12.1999998,0.0000000,0.0000000,180.0000000);
	CreateObject(3475,2107.5000000,2082.1999512,12.1999998,0.0000000,0.0000000,180.0000000);
	CreateObject(3749,2105.8000488,2070.1000977,15.6999998,0.0000000,0.0000000,90.0000000);
	CreateObject(3475,2104.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2098.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2092.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2086.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2080.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2074.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2068.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2062.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2056.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2050.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2044.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2038.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2032.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2026.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2020.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2014.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2008.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,2002.8000488,2103.1000977,12.1999998,0.0000000,0.0000000,270.0000000);
	CreateObject(3475,1998.5999756,2100.6000977,12.1999998,0.0000000,0.0000000,335.0000000);
	CreateObject(3475,1997.4000244,2035.0999756,12.1999998,0.0000000,0.0000000,0.0000000);
	CreateObject(3475,1997.4000244,2041.0999756,12.1999998,0.0000000,0.0000000,0.0000000);
	CreateObject(3475,1997.4000244,2047.0999756,12.1999998,0.0000000,0.0000000,0.0000000);
	CreateObject(3475,1997.4000244,2053.1000977,12.1999998,0.0000000,0.0000000,0.0000000);
	CreateObject(3475,1997.4000244,2059.1000977,12.1999998,0.0000000,0.0000000,0.0000000);
	CreateObject(3475,1997.4000244,2065.1000977,12.1999998,0.0000000,0.0000000,0.0000000);
	CreateObject(3475,1997.4000244,2071.1000977,12.1999998,0.0000000,0.0000000,0.0000000);
	CreateObject(3475,1997.4000244,2077.1000977,12.1999998,0.0000000,0.0000000,0.0000000);
	CreateObject(3475,1997.4000244,2083.1000977,12.1999998,0.0000000,0.0000000,0.0000000);
	CreateObject(3475,1997.4000244,2089.1000977,12.1999998,0.0000000,0.0000000,0.0000000);
	CreateObject(3475,1997.4000244,2095.1000977,12.1999998,0.0000000,0.0000000,0.0000000);

	//=======================================================================================================================
	//--------------------------------------------------------------- SAN FIERRO --------------------------------------------
	//=======================================================================================================================

	//----------------------------------------------------------- ENTRADA DE SAN FIERRO -------------------------------------
	CreateObject(972,-1772.8000488,-608.7000122,15.5000000,358.0000000,0.0000000,0.0000000);
	CreateObject(972,-1772.8000488,-633.0999756,16.7000008,357.0000000,0.0000000,0.0000000);
	CreateObject(972,-1772.6999512,-657.7000122,19.0000000,353.0000000,0.0000000,0.0000000);
	CreateObject(972,-1772.5999756,-682.2000122,22.2999992,352.0000000,0.0000000,0.0000000);
	CreateObject(972,-1779.9000244,-597.5000000,15.5000000,0.0000000,0.0000000,90.0000000);
	CreateObject(972,-1798.4000244,-597.5999756,15.3000002,0.0000000,0.0000000,90.0000000);
	CreateObject(972,-1766.9000244,-706.7999878,26.0000000,351.0000000,0.0000000,20.0000000);
	CreateObject(973,-1760.0999756,-566.0999756,16.2999992,0.0000000,0.0000000,180.0000000);
	CreateObject(973,-1750.8000488,-566.0999756,16.2999992,0.0000000,0.0000000,180.0000000);
	CreateObject(973,-1741.5000000,-566.0999756,16.2999992,0.0000000,0.0000000,180.0000000);
	CreateObject(973,-1769.4000244,-566.0999756,16.2999992,0.0000000,0.0000000,180.0000000);
	CreateObject(973,-1778.6999512,-566.0999756,16.2999992,0.0000000,0.0000000,180.0000000); 
	CreateObject(972,-1815.1999512,-608.9000244,15.1999998,0.0000000,0.0000000,3.0000000); 
	CreateObject(972,-1813.6999512,-633.7999878,15.6000004,357.0000000,0.0000000,3.0000000);
	CreateObject(972,-1812.0999756,-658.5999756,17.8999996,353.0000000,0.0000000,4.0000000);
	CreateObject(972,-1810.0000000,-683.2999878,21.5000000,351.0000000,0.0000000,6.0000000);
	CreateObject(972,-1807.8000488,-707.9000244,25.6000004,351.0000000,0.0000000,6.0000000);
	CreateObject(972,-1793.0999756,-714.0999756,27.0000000,1.0000000,0.0000000,270.0000000);
	CreateObject(972,-1775.4000244,-714.0999756,27.6000004,0.0000000,0.0000000,280.0000000);
	CreateObject(972,-1785.8000488,-720.5000000,30.0000000,0.0000000,0.0000000,90.0000000); 
	CreateObject(972,-1779.5999756,-712.7999878,30.0000000,0.0000000,0.0000000,273.0000000);
	CreateObject(1383,-1784.0999756,-668.9000244,40.0000000,0.0000000,0.0000000,0.0000000);
	CreateObject(1384,-1784.0999756,-668.9000244,72.5999985,0.0000000,0.0000000,0.0000000);
	CreateObject(1381,-1784.0999756,-619.2000122,76.3000031,0.0000000,0.0000000,0.0000000);
	CreateObject(8875,-1809.5999756,-597.0999756,21.6000004,0.0000000,0.0000000,135.0000000);
	CreateObject(8875,-1771.5000000,-596.2999878,21.6000004,0.0000000,0.0000000,45.0000000);
	CreateObject(3575,-1801.5000000,-603.7999878,17.8999996,0.0000000,0.0000000,0.0000000);
	CreateObject(3573,-1782.5999756,-600.0000000,18.2000008,0.0000000,0.0000000,0.0000000); 
	CreateObject(3573,-1797.5999756,-618.7000122,18.8999996,0.0000000,0.0000000,180.0000000);
	CreateObject(12930,-1783.5000000,-614.9000244,17.2999992,0.0000000,0.0000000,0.0000000);
	CreateObject(897,-1783.0000000,-636.5000000,18.0000000,0.0000000,0.0000000,0.0000000);
	CreateObject(900,-1781.6999512,-652.7000122,20.0000000,0.0000000,0.0000000,100.0000000);
	CreateObject(899,-1794.6999512,-639.0000000,18.0000000,0.0000000,0.0000000,0.0000000);
	CreateObject(807,-1782.1999512,-627.4000244,18.6000004,0.0000000,0.0000000,0.0000000);
	CreateObject(3931,-1780.0000000,-626.0999756,18.6000004,0.0000000,0.0000000,0.0000000);

	//--------------------- GRADES ESTADIO LS -----------------------------------
	CreateObject(970,2711.5000000,-1879.0000000,10.6000000,0.0000000,0.0000000,343.0000000);
	CreateObject(970,2707.5000000,-1877.7700000,10.6000000,0.0000000,0.0000000,343.0000000);
	CreateObject(970,2703.5000000,-1876.5500000,10.6000000,0.0000000,0.0000000,343.0000000);
	CreateObject(970,2699.6001000,-1875.3000000,10.6000000,0.0000000,0.0000000,341.0000000);
	CreateObject(970,2695.8999000,-1873.6000000,10.6000000,0.0000000,0.0000000,329.0000000);
	CreateObject(970,2692.3999000,-1871.5000000,10.6000000,0.0000000,0.0000000,329.0000000);
	CreateObject(970,2688.8999000,-1869.4000000,10.6000000,0.0000000,0.0000000,329.0000000);
	CreateObject(970,2665.3000000,-1847.2000000,10.6000000,0.0000000,0.0000000,129.0000000);
	CreateObject(970,2667.8999000,-1850.4000000,10.6000000,0.0000000,0.0000000,129.0000000);
	CreateObject(970,2670.5000000,-1853.6000000,10.6000000,0.0000000,0.0000000,129.0000000);
	CreateObject(970,2673.1001000,-1856.8000000,10.7000000,0.0000000,0.0000000,131.0000000);
	CreateObject(970,2676.1001000,-1859.6000000,10.6000000,0.0000000,0.0000000,140.0000000);
	CreateObject(970,2679.3000000,-1862.3000000,10.6000000,0.0000000,0.0000000,140.0000000);
	CreateObject(970,2682.5000000,-1865.0000000,10.6000000,0.0000000,0.0000000,140.0000000);
	CreateObject(1278,2685.6001000,-1867.3000000,-3.0000000,180.0000000,0.0000000,18.0000000);


    RemoveBuildingForPlayer(playerid, 1297, 2546.0859, -1475.1641, 26.3047, 0.25); //Lava jato de LS - Poste
    RemoveBuildingForPlayer(playerid, 1297, 2446.3359, -1426.4609, 26.2266, 0.25); //Rodriguez Ferro e Aço - Poste
	RemoveBuildingForPlayer(playerid, 1396, 2232.4375, -2458.5781, 36.1953, 0.25);
	RemoveBuildingForPlayer(playerid, 1378, 2232.4375, -2458.5781, 36.1953, 0.25);
	RemoveBuildingForPlayer(playerid, 3682, 2743.5078, -2193.2813, 36.5469, 0.25);
	RemoveBuildingForPlayer(playerid, 3289, 2653.3672, -2187.2813, 12.2813, 0.25);
	RemoveBuildingForPlayer(playerid, 3289, 2710.2500, -2197.8750, 12.2422, 0.25);
	RemoveBuildingForPlayer(playerid, 3289, 2717.1484, -2197.8750, 12.2422, 0.25);
	RemoveBuildingForPlayer(playerid, 3289, 2723.0469, -2197.8750, 12.2422, 0.25);
	RemoveBuildingForPlayer(playerid, 3288, 2662.4531, -2193.9297, 12.2188, 0.25);
	RemoveBuildingForPlayer(playerid, 3288, 2710.0313, -2190.0938, 12.2188, 0.25);
	RemoveBuildingForPlayer(playerid, 1396, 2637.0313, -2233.9609, 36.0703, 0.25);
	RemoveBuildingForPlayer(playerid, 1396, 2696.0781, -2233.9609, 36.1953, 0.25);
	RemoveBuildingForPlayer(playerid, 1396, 2750.9844, -2233.9609, 36.3125, 0.25);
	RemoveBuildingForPlayer(playerid, 3688, 2692.2266, -2209.3906, 17.8594, 0.25);
	RemoveBuildingForPlayer(playerid, 3744, 2723.7578, -2239.7500, 14.9609, 0.25);
	RemoveBuildingForPlayer(playerid, 3744, 2666.3984, -2239.1016, 15.2031, 0.25);
	RemoveBuildingForPlayer(playerid, 3745, 2694.8047, -2191.4453, 17.5938, 0.25);
	RemoveBuildingForPlayer(playerid, 3745, 2687.8047, -2191.4453, 17.5938, 0.25);
	RemoveBuildingForPlayer(playerid, 3745, 2680.8047, -2191.4453, 17.5938, 0.25);
	RemoveBuildingForPlayer(playerid, 3745, 2673.8047, -2191.4453, 17.5938, 0.25);
	RemoveBuildingForPlayer(playerid, 3769, 2750.2969, -2226.9922, 15.0469, 0.25);
	RemoveBuildingForPlayer(playerid, 3769, 2633.7656, -2227.1094, 15.1563, 0.25);
	RemoveBuildingForPlayer(playerid, 3779, 2634.1250, -2194.8438, 20.0078, 0.25);
	RemoveBuildingForPlayer(playerid, 3574, 2723.7578, -2239.7500, 14.9609, 0.25);
	RemoveBuildingForPlayer(playerid, 3574, 2666.3984, -2239.1016, 15.2031, 0.25);
	RemoveBuildingForPlayer(playerid, 1378, 2637.0313, -2233.9609, 36.0703, 0.25);
	RemoveBuildingForPlayer(playerid, 3625, 2633.7656, -2227.1094, 15.1563, 0.25);
	RemoveBuildingForPlayer(playerid, 1376, 2637.0156, -2228.6250, 31.5547, 0.25);
	RemoveBuildingForPlayer(playerid, 3621, 2692.2266, -2209.3906, 17.8594, 0.25);
	RemoveBuildingForPlayer(playerid, 1378, 2696.0781, -2233.9609, 36.1953, 0.25);
	RemoveBuildingForPlayer(playerid, 1376, 2696.0625, -2228.6250, 31.6797, 0.25);
	RemoveBuildingForPlayer(playerid, 1377, 2637.0313, -2203.1484, 38.8594, 0.25);
	RemoveBuildingForPlayer(playerid, 3257, 2662.4531, -2193.9297, 12.2188, 0.25);
	RemoveBuildingForPlayer(playerid, 3637, 2634.1250, -2194.8438, 20.0078, 0.25);
	RemoveBuildingForPlayer(playerid, 3258, 2653.3672, -2187.2813, 12.2813, 0.25);
	RemoveBuildingForPlayer(playerid, 3643, 2673.8047, -2191.4453, 17.5938, 0.25);
	RemoveBuildingForPlayer(playerid, 3643, 2680.8047, -2191.4453, 17.5938, 0.25);
	RemoveBuildingForPlayer(playerid, 1377, 2696.0781, -2203.1484, 38.9844, 0.25);
	RemoveBuildingForPlayer(playerid, 3643, 2687.8047, -2191.4453, 17.5938, 0.25);
	RemoveBuildingForPlayer(playerid, 3643, 2694.8047, -2191.4453, 17.5938, 0.25);
	RemoveBuildingForPlayer(playerid, 3258, 2710.2500, -2197.8750, 12.2422, 0.25);
	RemoveBuildingForPlayer(playerid, 3257, 2710.0313, -2190.0938, 12.2188, 0.25);
	RemoveBuildingForPlayer(playerid, 3258, 2717.1484, -2197.8750, 12.2422, 0.25);
	RemoveBuildingForPlayer(playerid, 3258, 2723.0469, -2197.8750, 12.2422, 0.25);
	RemoveBuildingForPlayer(playerid, 3625, 2750.2969, -2226.9922, 15.0469, 0.25);
	RemoveBuildingForPlayer(playerid, 1376, 2750.9688, -2228.6250, 31.7969, 0.25);
	RemoveBuildingForPlayer(playerid, 1377, 2750.9844, -2203.1484, 39.1016, 0.25);
	RemoveBuildingForPlayer(playerid, 1378, 2750.9844, -2233.9609, 36.3125, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2731.4766, -2189.0859, 19.4297, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2737.1563, -2186.5313, 21.4297, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2732.3906, -2185.6797, 22.8906, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2731.5391, -2188.3984, 14.5391, 0.25);
	RemoveBuildingForPlayer(playerid, 3673, 2743.5078, -2193.2813, 36.5469, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2747.2578, -2187.3906, 26.9141, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2747.2578, -2187.3906, 13.2500, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2740.7344, -2186.5313, 25.6016, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2750.8203, -2185.6797, 22.2813, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2749.2344, -2187.3906, 19.4297, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2753.5391, -2186.5313, 30.6250, 0.25);
	RemoveBuildingForPlayer(playerid, 3244, 2632.3906, -2073.6406, 12.7578, 0.25);
	RemoveBuildingForPlayer(playerid, 3244, 2632.3906, -2136.3281, 12.7578, 0.25);
	RemoveBuildingForPlayer(playerid, 3244, 2532.0313, -2074.6250, 12.9922, 0.25);
	RemoveBuildingForPlayer(playerid, 3682, 2673.0859, -2114.9063, 36.5469, 0.25);
	RemoveBuildingForPlayer(playerid, 3683, 2684.7656, -2088.0469, 20.1172, 0.25);
	RemoveBuildingForPlayer(playerid, 3289, 2679.2344, -2106.9766, 12.5391, 0.25);
	RemoveBuildingForPlayer(playerid, 3290, 2503.1250, -2073.3750, 12.4297, 0.25);
	RemoveBuildingForPlayer(playerid, 3290, 2515.4219, -2073.3750, 12.4063, 0.25);
	RemoveBuildingForPlayer(playerid, 3290, 2647.1016, -2073.3750, 12.4453, 0.25);
	RemoveBuildingForPlayer(playerid, 3290, 2658.7188, -2073.3750, 12.4453, 0.25);
	RemoveBuildingForPlayer(playerid, 3290, 2671.5000, -2073.3750, 12.4453, 0.25);
	RemoveBuildingForPlayer(playerid, 3686, 2169.1172, -2276.5859, 15.9063, 0.25);
	RemoveBuildingForPlayer(playerid, 3686, 2220.7813, -2261.0547, 15.9063, 0.25);
	RemoveBuildingForPlayer(playerid, 3744, 2193.2578, -2286.2891, 14.8125, 0.25);
	RemoveBuildingForPlayer(playerid, 5305, 2198.8516, -2213.9219, 14.8828, 0.25);
	RemoveBuildingForPlayer(playerid, 3747, 2234.3906, -2244.8281, 14.9375, 0.25);
	RemoveBuildingForPlayer(playerid, 3747, 2226.9688, -2252.1406, 14.9375, 0.25);
	RemoveBuildingForPlayer(playerid, 3747, 2219.4219, -2259.5234, 14.8828, 0.25);
	RemoveBuildingForPlayer(playerid, 3747, 2212.0938, -2267.0703, 14.9375, 0.25);
	RemoveBuildingForPlayer(playerid, 3747, 2204.6328, -2274.4141, 14.9375, 0.25);
	RemoveBuildingForPlayer(playerid, 3745, 2475.1016, -2073.4766, 17.8203, 0.25);
	RemoveBuildingForPlayer(playerid, 3745, 2482.0234, -2073.4766, 17.8203, 0.25);
	RemoveBuildingForPlayer(playerid, 3745, 2489.1016, -2073.4766, 17.8203, 0.25);
	RemoveBuildingForPlayer(playerid, 3745, 2496.0938, -2073.4766, 17.8203, 0.25);
	RemoveBuildingForPlayer(playerid, 3779, 2631.9141, -2098.5781, 20.0078, 0.25);
	RemoveBuildingForPlayer(playerid, 3779, 2653.9375, -2092.3359, 20.0078, 0.25);
	RemoveBuildingForPlayer(playerid, 1226, 2184.6250, -2308.3281, 17.4766, 0.25);
	RemoveBuildingForPlayer(playerid, 1226, 2202.8047, -2290.1016, 17.4766, 0.25);
	RemoveBuildingForPlayer(playerid, 3578, 2165.0703, -2288.9688, 13.2578, 0.25);
	RemoveBuildingForPlayer(playerid, 3574, 2193.2578, -2286.2891, 14.8125, 0.25);
	RemoveBuildingForPlayer(playerid, 3627, 2169.1172, -2276.5859, 15.9063, 0.25);
	RemoveBuildingForPlayer(playerid, 3569, 2204.6328, -2274.4141, 14.9375, 0.25);
	RemoveBuildingForPlayer(playerid, 3569, 2212.0938, -2267.0703, 14.9375, 0.25);
	RemoveBuildingForPlayer(playerid, 3627, 2220.7813, -2261.0547, 15.9063, 0.25);
	RemoveBuildingForPlayer(playerid, 3569, 2219.4219, -2259.5234, 14.8828, 0.25);
	RemoveBuildingForPlayer(playerid, 3578, 2194.4766, -2242.8750, 13.2578, 0.25);
	RemoveBuildingForPlayer(playerid, 1226, 2217.2188, -2250.3594, 16.3672, 0.25);
	RemoveBuildingForPlayer(playerid, 3569, 2226.9688, -2252.1406, 14.9375, 0.25);
	RemoveBuildingForPlayer(playerid, 3569, 2234.3906, -2244.8281, 14.9375, 0.25);
	RemoveBuildingForPlayer(playerid, 3578, 2235.1641, -2231.8516, 13.2578, 0.25);
	RemoveBuildingForPlayer(playerid, 5244, 2198.8516, -2213.9219, 14.8828, 0.25);
	RemoveBuildingForPlayer(playerid, 1226, 2240.7813, -2240.8984, 16.3672, 0.25);
	RemoveBuildingForPlayer(playerid, 3567, 2446.8281, -2075.8438, 13.2578, 0.25);
	RemoveBuildingForPlayer(playerid, 3567, 2438.3594, -2075.8438, 13.2578, 0.25);
	RemoveBuildingForPlayer(playerid, 3643, 2489.1016, -2073.4766, 17.8203, 0.25);
	RemoveBuildingForPlayer(playerid, 3643, 2482.0234, -2073.4766, 17.8203, 0.25);
	RemoveBuildingForPlayer(playerid, 3643, 2475.1016, -2073.4766, 17.8203, 0.25);
	RemoveBuildingForPlayer(playerid, 3643, 2496.0938, -2073.4766, 17.8203, 0.25);
	RemoveBuildingForPlayer(playerid, 3256, 2515.4219, -2073.3750, 12.4063, 0.25);
	RemoveBuildingForPlayer(playerid, 3256, 2503.1250, -2073.3750, 12.4297, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2663.0547, -2121.6563, 30.6250, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2665.7734, -2122.5078, 22.2813, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2667.3594, -2120.7969, 19.4297, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2669.3359, -2120.7969, 26.9141, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2669.3359, -2120.7969, 13.2500, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2679.4375, -2121.6563, 21.4297, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2675.8594, -2121.6563, 25.6016, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2684.2031, -2122.5078, 22.8906, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2685.0547, -2119.7891, 14.5391, 0.25);
	RemoveBuildingForPlayer(playerid, 3675, 2685.1172, -2119.1016, 19.4297, 0.25);
	RemoveBuildingForPlayer(playerid, 3637, 2631.9141, -2098.5781, 20.0078, 0.25);
	RemoveBuildingForPlayer(playerid, 3637, 2653.9375, -2092.3359, 20.0078, 0.25);
	RemoveBuildingForPlayer(playerid, 3673, 2673.0859, -2114.9063, 36.5469, 0.25);
	RemoveBuildingForPlayer(playerid, 3258, 2679.2344, -2106.9766, 12.5391, 0.25);
	RemoveBuildingForPlayer(playerid, 3674, 2682.3203, -2114.5313, 39.0313, 0.25);
	RemoveBuildingForPlayer(playerid, 3636, 2684.7656, -2088.0469, 20.1172, 0.25);
	RemoveBuildingForPlayer(playerid, 3256, 2647.1016, -2073.3750, 12.4453, 0.25);
	RemoveBuildingForPlayer(playerid, 3256, 2658.7188, -2073.3750, 12.4453, 0.25);
	RemoveBuildingForPlayer(playerid, 3256, 2671.5000, -2073.3750, 12.4453, 0.25);
	RemoveBuildingForPlayer(playerid, 11372, -2076.4375, -107.9297, 36.9688, 0.25);
	RemoveBuildingForPlayer(playerid, 11014, -2076.4375, -107.9297, 36.9688, 0.25);
	RemoveBuildingForPlayer(playerid, 8737, 2814.3438, 993.8438, 13.1406, 0.25);
	RemoveBuildingForPlayer(playerid, 8738, 2867.9766, 976.5078, 14.7422, 0.25);
	RemoveBuildingForPlayer(playerid, 8960, 2787.0000, 953.4375, 13.2500, 0.25);
	RemoveBuildingForPlayer(playerid, 1219, 2806.6094, 892.3828, 9.9766, 0.25);
	RemoveBuildingForPlayer(playerid, 3458, 2818.4609, 928.6484, 11.2422, 0.25);
	RemoveBuildingForPlayer(playerid, 8884, 2787.0000, 953.4375, 13.2500, 0.25);
	RemoveBuildingForPlayer(playerid, 1231, 2801.9219, 933.8281, 12.7109, 0.25);
	RemoveBuildingForPlayer(playerid, 1231, 2812.2266, 933.8281, 12.7109, 0.25);
	RemoveBuildingForPlayer(playerid, 1231, 2823.4609, 933.8281, 12.7109, 0.25);
	RemoveBuildingForPlayer(playerid, 3458, 2818.4609, 938.7188, 11.2422, 0.25);
	RemoveBuildingForPlayer(playerid, 1231, 2834.5078, 933.8281, 12.7109, 0.25);
	RemoveBuildingForPlayer(playerid, 1365, 2849.5391, 945.0156, 10.7813, 0.25);
	RemoveBuildingForPlayer(playerid, 1219, 2858.2734, 944.9766, 9.9766, 0.25);
	RemoveBuildingForPlayer(playerid, 1343, 2863.4688, 946.0156, 10.4844, 0.25);
	RemoveBuildingForPlayer(playerid, 1344, 2879.6484, 945.9688, 10.5391, 0.25);
	RemoveBuildingForPlayer(playerid, 1358, 2796.8438, 977.6953, 10.8047, 0.25);
	RemoveBuildingForPlayer(playerid, 1365, 2796.6016, 984.8203, 10.7813, 0.25);
	RemoveBuildingForPlayer(playerid, 1219, 2796.5469, 996.7578, 9.9766, 0.25);
	RemoveBuildingForPlayer(playerid, 1219, 2796.5469, 1000.3516, 9.9766, 0.25);
	RemoveBuildingForPlayer(playerid, 8546, 2814.3438, 993.8438, 13.1406, 0.25);
	RemoveBuildingForPlayer(playerid, 1219, 2844.0000, 967.4063, 9.9766, 0.25);
	RemoveBuildingForPlayer(playerid, 1219, 2844.0000, 964.7422, 9.9766, 0.25);
	RemoveBuildingForPlayer(playerid, 1219, 2846.4688, 986.8516, 9.9766, 0.25);
	RemoveBuildingForPlayer(playerid, 1219, 2846.4688, 980.0391, 9.9766, 0.25);
	RemoveBuildingForPlayer(playerid, 8545, 2867.9766, 976.5078, 14.7422, 0.25);
	RemoveBuildingForPlayer(playerid, 7676, 1606.4219, 2392.7031, 15.8125, 0.25);
	RemoveBuildingForPlayer(playerid, 7677, 1587.8828, 2301.2188, 13.8125, 0.25);
	RemoveBuildingForPlayer(playerid, 7678, 1672.3906, 2382.2500, 15.9219, 0.25);
	RemoveBuildingForPlayer(playerid, 7679, 1743.5156, 2314.5391, 15.8125, 0.25);
	RemoveBuildingForPlayer(playerid, 7516, 1587.8828, 2301.2188, 13.8125, 0.25);
	RemoveBuildingForPlayer(playerid, 3474, 1591.3203, 2368.4609, 16.7422, 0.25);
	RemoveBuildingForPlayer(playerid, 7515, 1606.4219, 2392.7031, 15.8125, 0.25);
	RemoveBuildingForPlayer(playerid, 1245, 1637.9219, 2396.5625, 11.1719, 0.25);
	RemoveBuildingForPlayer(playerid, 7527, 1672.3906, 2382.2500, 15.9219, 0.25);
	RemoveBuildingForPlayer(playerid, 3474, 1692.0391, 2292.8906, 16.7422, 0.25);
	RemoveBuildingForPlayer(playerid, 1278, 1716.4375, 2347.2031, 24.0078, 0.25);
	RemoveBuildingForPlayer(playerid, 1245, 1704.2891, 2382.1406, 11.1719, 0.25);
	RemoveBuildingForPlayer(playerid, 7561, 1743.5156, 2314.5391, 15.8125, 0.25);
	RemoveBuildingForPlayer(playerid, 3447, 2044.2891, 2199.6719, 17.3203, 0.25);
	RemoveBuildingForPlayer(playerid, 3447, 2022.5781, 2199.6719, 17.3203, 0.25);
	RemoveBuildingForPlayer(playerid, 13192, 164.7109, -234.1875, 0.4766, 0.25);
	RemoveBuildingForPlayer(playerid, 13193, 173.5156, -323.8203, 0.5156, 0.25);
	RemoveBuildingForPlayer(playerid, 13194, 140.5938, -305.3906, 5.5938, 0.25);
	RemoveBuildingForPlayer(playerid, 13195, 36.8281, -256.2266, 0.4688, 0.25);
	RemoveBuildingForPlayer(playerid, 3377, -207.6563, -246.7344, 1.5781, 0.25);
	RemoveBuildingForPlayer(playerid, 3377, -196.7188, -246.1641, 1.5781, 0.25);
	RemoveBuildingForPlayer(playerid, 3377, -149.9141, -324.3438, 1.5781, 0.25);
	RemoveBuildingForPlayer(playerid, 12932, -117.9609, -337.4531, 3.6172, 0.25);
	RemoveBuildingForPlayer(playerid, 12858, 272.0625, -359.7656, 8.9531, 0.25);
	RemoveBuildingForPlayer(playerid, 3378, -149.9141, -324.3438, 1.5781, 0.25);
	RemoveBuildingForPlayer(playerid, 1426, 29.1719, -292.2734, 1.4063, 0.25);
	RemoveBuildingForPlayer(playerid, 1431, 36.4297, -291.0625, 1.5703, 0.25);
	RemoveBuildingForPlayer(playerid, 1426, 24.5938, -291.7578, 1.4063, 0.25);
	RemoveBuildingForPlayer(playerid, 12934, -184.5781, -289.8984, 3.7109, 0.25);
	RemoveBuildingForPlayer(playerid, 1438, 29.2344, -286.0547, 1.2188, 0.25);
	RemoveBuildingForPlayer(playerid, 1440, 32.4063, -289.2188, 1.6484, 0.25);
	RemoveBuildingForPlayer(playerid, 1438, 33.6016, -279.3516, 1.1172, 0.25);
	RemoveBuildingForPlayer(playerid, 12861, 36.8281, -256.2266, 0.4688, 0.25);
	RemoveBuildingForPlayer(playerid, 3378, -207.6563, -246.7344, 1.5781, 0.25);
	RemoveBuildingForPlayer(playerid, 1450, 43.4844, -252.5703, 1.2031, 0.25);
	RemoveBuildingForPlayer(playerid, 1449, 43.1094, -254.9609, 1.2188, 0.25);
	RemoveBuildingForPlayer(playerid, 12859, 173.5156, -323.8203, 0.5156, 0.25);
	RemoveBuildingForPlayer(playerid, 13198, 140.5938, -305.3906, 5.5938, 0.25);
	RemoveBuildingForPlayer(playerid, 12956, 96.3281, -261.1953, 3.8594, 0.25);
	RemoveBuildingForPlayer(playerid, 3378, -196.7188, -246.1641, 1.5781, 0.25);
	RemoveBuildingForPlayer(playerid, 12860, 164.7109, -234.1875, 0.4766, 0.25);
	RemoveBuildingForPlayer(playerid, 17349, -542.0078, -522.8438, 29.5938, 0.25);
	RemoveBuildingForPlayer(playerid, 1415, -541.4297, -561.2266, 24.5859, 0.25);
	RemoveBuildingForPlayer(playerid, 17012, -542.0078, -522.8438, 29.5938, 0.25);
	RemoveBuildingForPlayer(playerid, 1415, -513.7578, -561.0078, 24.5859, 0.25);
	RemoveBuildingForPlayer(playerid, 1441, -503.6172, -540.5313, 25.2266, 0.25);
	RemoveBuildingForPlayer(playerid, 1415, -502.6094, -528.6484, 24.5859, 0.25);
	RemoveBuildingForPlayer(playerid, 1440, -502.1172, -521.0313, 25.0234, 0.25);
	RemoveBuildingForPlayer(playerid, 1441, -502.4063, -513.0156, 25.2266, 0.25);
	RemoveBuildingForPlayer(playerid, 1415, -620.4141, -490.5078, 24.5859, 0.25);
	RemoveBuildingForPlayer(playerid, 1415, -619.6250, -473.4531, 24.5859, 0.25);
	RemoveBuildingForPlayer(playerid, 1440, -553.6875, -481.6328, 25.0234, 0.25);
	RemoveBuildingForPlayer(playerid, 1441, -554.4531, -496.1797, 25.1641, 0.25);
	RemoveBuildingForPlayer(playerid, 1441, -537.0391, -469.1172, 25.2266, 0.25);
	RemoveBuildingForPlayer(playerid, 1440, -516.9453, -496.6484, 25.0234, 0.25);
	RemoveBuildingForPlayer(playerid, 1440, -503.1250, -509.0000, 25.0234, 0.25);
	RemoveBuildingForPlayer(playerid, 7833, 1064.8359, 1869.7813, 13.9219, 0.25);
	RemoveBuildingForPlayer(playerid, 7835, 1162.5625, 1947.8906, 15.8125, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 1989.3516, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 1999.9063, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 2005.1797, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 2010.4531, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 1994.6250, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 2031.5625, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 2036.8359, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 2026.2891, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 2015.7344, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 2021.0078, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1130.6719, 1850.9141, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1413, 1129.5391, 1845.7656, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1413, 1132.3750, 1855.8906, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 7834, 1064.8359, 1869.7813, 13.9219, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1134.5938, 1860.6719, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1136.8281, 1865.4531, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1139.0547, 1870.2344, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1141.2891, 1875.0234, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1147.9766, 1889.3672, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1145.7500, 1884.5859, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1143.5156, 1879.8047, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1150.2031, 1894.1484, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1152.4375, 1898.9297, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1154.6641, 1903.7109, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1413, 1158.4297, 1905.8438, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1163.6797, 1905.3906, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1413, 1167.5625, 1907.4375, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1170.1875, 1912.0078, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1172.8281, 1916.5781, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 7836, 1162.5625, 1947.8906, 15.8125, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1175.4688, 1921.1484, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1413, 1176.7656, 1926.0391, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 1931.3125, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 1936.5859, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 1941.8594, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 1947.1406, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 1952.4141, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 3474, 1124.6797, 1963.3672, 16.7422, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 1957.6875, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 1968.2422, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 1962.9688, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 1978.7969, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 1973.5234, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1176.7578, 1984.0703, 11.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 1377, 2201.6250, -2458.5781, 38.9844, 0.25);
	RemoveBuildingForPlayer(playerid, 1376, 2227.1016, -2458.5938, 31.6797, 0.25);
	RemoveBuildingForPlayer(playerid, 3686, 2448.1328, -2075.6328, 16.0469, 0.25);
	RemoveBuildingForPlayer(playerid, 3627, 2448.1328, -2075.6328, 16.0469, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 2410.5859, -2145.5313, 13.7500, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 2415.8672, -2145.4375, 13.7500, 0.25);
	RemoveBuildingForPlayer(playerid, 1226, 2610.5859, -2231.1016, 16.2109, 0.25);
	RemoveBuildingForPlayer(playerid, 3674, 2734.2734, -2193.6563, 39.0313, 0.25);
	RemoveBuildingForPlayer(playerid, 3460, 1076.2188, 1948.9219, 13.7656, 0.25);
	RemoveBuildingForPlayer(playerid, 3777, 831.9609, -1191.1406, 25.0391, 0.25);
	RemoveBuildingForPlayer(playerid, 3777, 868.1328, -1191.1406, 25.0391, 0.25);
	RemoveBuildingForPlayer(playerid, 5926, 816.3359, -1217.1484, 26.4453, 0.25);
	RemoveBuildingForPlayer(playerid, 3777, 902.3359, -1191.1406, 25.0391, 0.25);
	RemoveBuildingForPlayer(playerid, 6005, 895.2578, -1256.9297, 31.2344, 0.25);
	RemoveBuildingForPlayer(playerid, 5836, 816.3359, -1217.1484, 26.4453, 0.25);
	RemoveBuildingForPlayer(playerid, 3776, 831.9609, -1191.1406, 25.0391, 0.25);
	RemoveBuildingForPlayer(playerid, 3776, 868.1328, -1191.1406, 25.0391, 0.25);
	RemoveBuildingForPlayer(playerid, 5838, 895.2578, -1256.9297, 31.2344, 0.25);
	RemoveBuildingForPlayer(playerid, 3776, 902.3359, -1191.1406, 25.0391, 0.25);
	RemoveBuildingForPlayer(playerid, 1297, 937.5547, -1213.8672, 18.5938, 0.25);
	RemoveBuildingForPlayer(playerid, 5855, 1095.6797, -1212.7813, 18.2891, 0.25);
	RemoveBuildingForPlayer(playerid, 5822, 1123.8203, -1198.8516, 25.7188, 0.25);
	RemoveBuildingForPlayer(playerid, 8963, 2885.5313, 919.2266, 13.2500, 0.25);
	RemoveBuildingForPlayer(playerid, 1278, 2806.2109, 838.6094, 23.9297, 0.25);
	RemoveBuildingForPlayer(playerid, 1278, 2866.0313, 838.6094, 23.9297, 0.25);
	RemoveBuildingForPlayer(playerid, 1278, 2782.6641, 851.7656, 23.9297, 0.25);
	RemoveBuildingForPlayer(playerid, 1278, 2889.7344, 851.7656, 23.9297, 0.25);
	RemoveBuildingForPlayer(playerid, 1278, 2782.6641, 899.2813, 23.9297, 0.25);
	RemoveBuildingForPlayer(playerid, 1278, 2889.6172, 895.2109, 23.9297, 0.25);
	RemoveBuildingForPlayer(playerid, 1278, 2782.6641, 929.2969, 23.9297, 0.25);
	RemoveBuildingForPlayer(playerid, 8883, 2885.5313, 919.2266, 13.2500, 0.25);
	RemoveBuildingForPlayer(playerid, 1278, 2889.7266, 943.2656, 23.9297, 0.25);
	RemoveBuildingForPlayer(playerid, 1278, 2782.6641, 986.6719, 23.9297, 0.25);
	RemoveBuildingForPlayer(playerid, 1278, 2806.2109, 1017.9375, 23.9297, 0.25);
	RemoveBuildingForPlayer(playerid, 1278, 2866.0313, 1017.9375, 23.9297, 0.25);
	RemoveBuildingForPlayer(playerid, 1278, 2889.7266, 986.6719, 23.9297, 0.25);
	RemoveBuildingForPlayer(playerid, 7315, 2156.0234, 2073.0781, 34.3984, 0.25);
	RemoveBuildingForPlayer(playerid, 7316, 2156.0234, 2073.0781, 34.3984, 0.25);
	RemoveBuildingForPlayer(playerid, 7720, 2074.7578, 2048.0703, 9.8438, 0.25);
	RemoveBuildingForPlayer(playerid, 7531, 2074.7578, 2048.0703, 9.8438, 0.25);
	RemoveBuildingForPlayer(playerid, 7918, 2074.7578, 2048.0703, 9.8438, 0.25);
	RemoveBuildingForPlayer(playerid, 1522, 2084.7031, 2073.2734, 10.0391, 0.25);
	RemoveBuildingForPlayer(playerid, 955, 2085.7734, 2071.3594, 10.4531, 0.25);
	RemoveBuildingForPlayer(playerid, 3509, 2137.3984, 2075.7969, 9.7656, 0.25);
	RemoveBuildingForPlayer(playerid, 7952, 2137.1953, 2079.9141, 10.5313, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1757.3203, 2286.3828, 11.0625, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1757.3203, 2291.6641, 11.0625, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1757.3203, 2296.9063, 11.0625, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1757.3203, 2302.1484, 11.0625, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1757.3203, 2317.9063, 11.0625, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1757.3203, 2312.6641, 11.0625, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1757.3203, 2307.4219, 11.0625, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1757.3203, 2333.6719, 11.0625, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1757.3203, 2328.4297, 11.0625, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1757.3203, 2323.1875, 11.0625, 0.25);
	RemoveBuildingForPlayer(playerid, 1412, 1757.3203, 2338.9453, 11.0625, 0.25);
	RemoveBuildingForPlayer(playerid, 7663, 1949.0313, 2068.7813, 12.1094, 0.25);

	TextDrawHideForPlayer(playerid, Carregando);
	TextDrawHideForPlayer(playerid, Carregando1);
	TextDrawHideForPlayer(playerid, Carregando2);
	TextDrawHideForPlayer(playerid, Carregando3);
	SendClientMessage(playerid, 0x00BFFFFF, "Bem vindo ao {FFFF00}Carga {FFFF00}Pesada {FFFF00}Brasil");
	SendClientMessage(playerid, 0x00BFFFFF, "Lembre-se de ler as {FFFF00}/regras {00BFFF}antes de jogar!");
	SendClientMessage(playerid, 0x00BFFFFF, "Digite {FFFF00}/comandos {00BFFF}para saber todos os comandos do jogo.");
	SendClientMessage(playerid, 0x00BFFFFF, "Digite {FFFF00}/ajuda {00BFFF}caso tenha dúvida em alguma coisa.");
	SendClientMessage(playerid, 0x00BFFFFF, "Digite {FFFF00}/creditos {00BFFF} para saber quem participou da criação do gamemode.");
    new
        query[128],
        playername[MAX_PLAYER_NAME];

    GetPlayerName(playerid, playername, sizeof(playername));
    mysql_format(mysql, query, sizeof(query), "SELECT `Senha`, `ID` FROM `contas` WHERE `Nome` = '%e' LIMIT 1", playername);
    mysql_tquery(mysql, query, "ChecarConta", "i", playerid);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	if(PlayerInfo[playerid][pLogado] == false)
	{
		return 1;
	}
	if(PlayerInfo[playerid][pLogado] == true)
	{
	    SetPlayerColor(playerid, 0xFFFFFFFF);
        SendDeathMessage(INVALID_PLAYER_ID, playerid, 201);
	}
    new
        query[150];
    mysql_format(mysql, query, sizeof(query), "UPDATE `contas` SET `Dinheiro` = %d, `Pontos` = %d, `AdminLevel` = %d, `MsgBoasVindas` = %d WHERE `ID` = %d", PlayerInfo[playerid][pDinheiro], PlayerInfo[playerid][pPontos], PlayerInfo[playerid][pAdmin], PlayerInfo[playerid][MsgBoasVindas], PlayerInfo[playerid][pID]);
    mysql_tquery(mysql, query, "", "");
	return 1;
}

public OnPlayerCommandPerformed(playerid, cmdtext[], success)
{
	new string[128];
	format(string,128,"[ERRO] O comando {FFFF00}%s {FF0000}não existe. Digite {FFFF00}/comandos {FF0000}para ver todos os comandos.", cmdtext);
    if(!success) SendClientMessage(playerid, 0xFF0000AA, string);
    return 1;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
	return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
    TextDrawHideForPlayer(playerid, Velocimetro);
    TextDrawShowForPlayer(playerid, SiteCPB);
	return 1;
}

public OnPlayerText(playerid, text[])
{
    if(text[0] == '!' && PlayerInfo[playerid][pAdmin] > 0)
	{
 		new string[128];
		format(string,128,"[Chat Admin] %s %s (id:%i): %s", CargoAdmin(playerid), NomedoPlayer(playerid), playerid, text[1]);
		AdminChat(COR_ROSA, string);
	 	return 0;
	}
	return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
	if(newstate == PLAYER_STATE_DRIVER)
	{
	    TextDrawHideForPlayer(playerid, SiteCPB);
	    TextDrawShowForPlayer(playerid, Velocimetro);
	    new pvehiclemodel = GetVehicleModel(GetPlayerVehicleID(playerid));
		new Ponto = GetPlayerScore(playerid);
		if(Ponto < 25 && pvehiclemodel == 403 ||Ponto < 25 && pvehiclemodel == 482 || Ponto < 50 && pvehiclemodel == 514 || Ponto < 50 && pvehiclemodel == 456 || Ponto < 75 && pvehiclemodel == 515)
		{
			SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você não tem pontos suficientes para trabalhar com esse caminhão! Veja /pontos.");
			RemovePlayerFromVehicle(playerid);
			return 1;
		}
		if(PlayerInfo[playerid][pClasse] != Caminhoneiro && pvehiclemodel == 440 || PlayerInfo[playerid][pClasse] != Caminhoneiro && pvehiclemodel == 482 || PlayerInfo[playerid][pClasse] != Caminhoneiro && pvehiclemodel == 414 || PlayerInfo[playerid][pClasse] != Caminhoneiro && pvehiclemodel == 499 || PlayerInfo[playerid][pClasse] != Caminhoneiro && pvehiclemodel == 498 || PlayerInfo[playerid][pClasse] != Caminhoneiro && pvehiclemodel == 456)
		{
		    SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você não é caminhoneiro, então não pode pegar nenhum caminhão.");
		    RemovePlayerFromVehicle(playerid);
		    return 1;
		}
		if(PlayerInfo[playerid][pClasse] != Caminhoneiro && pvehiclemodel == 403 || PlayerInfo[playerid][pClasse] != Caminhoneiro && pvehiclemodel == 455 || PlayerInfo[playerid][pClasse] != Caminhoneiro && pvehiclemodel == 514 || PlayerInfo[playerid][pClasse] != Caminhoneiro && pvehiclemodel == 578 || PlayerInfo[playerid][pClasse] != Caminhoneiro && pvehiclemodel == 515)
		{
		    SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você não é caminhoneiro, então não pode pegar nenhum caminhão.");
		    RemovePlayerFromVehicle(playerid);
		    return 1;
		}
		if(PlayerInfo[playerid][pClasse] != Policia && pvehiclemodel == 596 || PlayerInfo[playerid][pClasse] != Policia && pvehiclemodel == 599 || PlayerInfo[playerid][pClasse] != Policia && pvehiclemodel == 523)
		{
		    SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você não é policial, então não pode pegar nenhum carro de polícia.");
		    RemovePlayerFromVehicle(playerid);
		}
		else
		{
  			return 0;
		}
	}
	if(newstate == PLAYER_STATE_ONFOOT)
	{
	    TextDrawShowForPlayer(playerid, SiteCPB);
	    TextDrawHideForPlayer(playerid, Velocimetro);
	}
	return 1;
}
public OnPlayerSpawn(playerid)
{
	TextDrawShowForPlayer(playerid, LogoC);
	TextDrawShowForPlayer(playerid, LogoP);
	TextDrawShowForPlayer(playerid, LogoB);
	TextDrawShowForPlayer(playerid, SiteCPB);
	TextDrawShowForPlayer(playerid, DataeHora);
 	TextDrawShowForPlayer(playerid, DinheiroR);
	SetPlayerInterior(playerid,0);
	TogglePlayerClock(playerid,0);
	TextDrawHideForPlayer(playerid, Velocimetro);
	if(PlayerInfo[playerid][pClasse] == Caminhoneiro)
	{
	    SetPlayerColor(playerid, 0xFFFF00FF);
	}
	if(PlayerInfo[playerid][pClasse] == Policia)
	{
	    SetPlayerColor(playerid, 0x0000FFFF);
	}
	if(PlayerInfo[playerid][pClasse] == MotoristadeOnibus)
	{
	    SetPlayerColor(playerid, 0xFF8000FF);
	}
	if(PlayerInfo[playerid][pClasse] == Mecanico)
	{
	    SetPlayerColor(playerid, 0x00C000FF);
	}
	return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
	switch (PlayerInfo[playerid][pClasse])
	{
	    case Caminhoneiro:
	        Caminhoneiro_EntrouCP(playerid);
 	}
	return 1;
}

public OnPlayerEnterRaceCheckpoint(playerid)
{
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    SendDeathMessage(killerid, playerid, reason);
    TextDrawHideForPlayer(playerid, Velocimetro);
   	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
    TextDrawHideForPlayer(playerid, LogoC);
	TextDrawHideForPlayer(playerid, LogoP);
	TextDrawHideForPlayer(playerid, LogoB);
	TextDrawHideForPlayer(playerid, SiteCPB);
	TextDrawHideForPlayer(playerid, DataeHora);
	TextDrawHideForPlayer(playerid, Velocimetro);
	TextDrawHideForPlayer(playerid, DinheiroR);
    SetPlayerInterior(playerid,5);
	SetPlayerPos(playerid,1274.07, -792.76, 1083.60);
	SetPlayerFacingAngle(playerid, 0.0);
	SetPlayerCameraPos(playerid,1270.81,-787.66,1085.50);
	SetPlayerCameraLookAt(playerid,1274.07, -792.76, 1084.60);
	switch (classid)
	{
		case 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11:
		{
            GameTextForPlayer(playerid, "Caminhoneiro", 1500, 6);
			PlayerInfo[playerid][pClasse] = Caminhoneiro;
		}
		case 12, 13, 14, 15, 16:
		{
		    GameTextForPlayer(playerid, "Policial", 1500, 6);
		    PlayerInfo[playerid][pClasse] = Policia;
		}
		case 17, 18, 19:
		{
		    GameTextForPlayer(playerid, "Mecanico", 1500, 6);
		    PlayerInfo[playerid][pClasse] = Mecanico;
		}
		case 20, 21:
		{
		    GameTextForPlayer(playerid, "Motorista de Onibus", 1500, 6);
		    PlayerInfo[playerid][pClasse] = MotoristadeOnibus;
		}
	}
	
	new Index, Float:x4, Float:y4, Float:z4, Float:Angle;
	if (PlayerInfo[playerid][pClasse] == Policia)
	{
	    Index = random(sizeof(SpawnPolicial));
		x4 = SpawnPolicial[Index][SpawnX];
		y4 = SpawnPolicial[Index][SpawnY];
		z4 = SpawnPolicial[Index][SpawnZ];
		Angle = SpawnPolicial[Index][SpawnAngle];
		SetSpawnInfo(playerid, 0, GetPlayerSkin(playerid), x4, y4, z4, Angle, 0, 0, 0, 0, 0, 0);
	}
	if (PlayerInfo[playerid][pPontos] < 25 && PlayerInfo[playerid][pClasse] == Caminhoneiro)
	{
		Index = random(sizeof(SpawnCaminhao25pontos));
		x4 = SpawnCaminhao25pontos[Index][SpawnX];
		y4 = SpawnCaminhao25pontos[Index][SpawnY];
		z4 = SpawnCaminhao25pontos[Index][SpawnZ];
		Angle = SpawnCaminhao25pontos[Index][SpawnAngle];
		SetSpawnInfo(playerid, 0, GetPlayerSkin(playerid), x4, y4, z4, Angle, 0, 0, 0, 0, 0, 0);
	}
	if (PlayerInfo[playerid][pPontos] > 25 && PlayerInfo[playerid][pPontos] < 49 && PlayerInfo[playerid][pClasse] == Caminhoneiro)
	{
	    Index = random(sizeof(SpawnCaminhao50pontos));
	    x4 = SpawnCaminhao50pontos[Index][SpawnX];
	    y4 = SpawnCaminhao50pontos[Index][SpawnY];
	    z4 = SpawnCaminhao50pontos[Index][SpawnZ];
	    Angle = SpawnCaminhao50pontos[Index][SpawnAngle];
	    SetSpawnInfo(playerid, 0, GetPlayerSkin(playerid), x4, y4, z4, Angle, 0, 0, 0, 0, 0, 0);
	}
	if (PlayerInfo[playerid][pPontos] > 50 && PlayerInfo[playerid][pPontos] < 75 && PlayerInfo[playerid][pClasse] == Caminhoneiro)
	{
	    Index = random(sizeof(SpawnCaminhao75pontos));
	    x4 = SpawnCaminhao75pontos[Index][SpawnX];
	    y4 = SpawnCaminhao75pontos[Index][SpawnY];
	    z4 = SpawnCaminhao75pontos[Index][SpawnZ];
	    Angle = SpawnCaminhao75pontos[Index][SpawnAngle];
	    SetSpawnInfo(playerid, 0, GetPlayerSkin(playerid), x4, y4, z4, Angle, 0, 0, 0, 0, 0, 0);
	}
	if(PlayerInfo[playerid][pPontos] >= 75 && PlayerInfo[playerid][pClasse] == Caminhoneiro)
	{
	    Index = random(sizeof(SpawnCaminhao75maispontos));
	    x4 = SpawnCaminhao75maispontos[Index][SpawnX];
	    y4 = SpawnCaminhao75maispontos[Index][SpawnY];
	    z4 = SpawnCaminhao75maispontos[Index][SpawnZ];
	    Angle = SpawnCaminhao75maispontos[Index][SpawnAngle];
	    SetSpawnInfo(playerid, 0, GetPlayerSkin(playerid), x4, y4, z4, Angle, 0, 0, 0, 0, 0, 0);
	}
	else
	{
	    SetSpawnInfo(playerid, 0, GetPlayerSkin(playerid), x4, y4, z4, Angle, 0, 0, 0, 0, 0, 0);
	}
	return 1;
}

public OnPlayerRequestSpawn(playerid)
{
	if(PlayerInfo[playerid][pLogado] == false)
	{
	    SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você foi kickado por tentar nascer sem digitar a senha");
	    Kick(playerid);
	}
    TextDrawShowForPlayer(playerid, LogoC);
	TextDrawShowForPlayer(playerid, LogoP);
	TextDrawShowForPlayer(playerid, LogoB);
	TextDrawShowForPlayer(playerid, SiteCPB);
	TextDrawShowForPlayer(playerid, DataeHora);
	SetPlayerScore(playerid, PlayerInfo[playerid][pPontos]);
    if(PlayerInfo[playerid][MsgBoasVindas] == 0)
	{
	    new stringt[sizeof(Bemvindo)*128];
		for(new i = 0; i <sizeof(Bemvindo); i ++)
   		format(stringt,sizeof(stringt),"%s\n  %s",stringt,Bemvindo[i]);
		ShowPlayerDialog(playerid, 24, DIALOG_STYLE_MSGBOX, "Carga Pesada Brasil - BOAS VINDAS", stringt, "Confirma", "");
		PlayerInfo[playerid][MsgBoasVindas] = 1;
	}
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch( dialogid )
    {
        case DialogoLogin:
        {
            if(!response) Kick(playerid);

            new
                hashpass[129],
                query[100],
                playername[MAX_PLAYER_NAME];

            GetPlayerName(playerid, playername, sizeof(playername));
            WP_Hash(hashpass, sizeof(hashpass), inputtext);
            if(!strcmp(hashpass, PlayerInfo[playerid][pSenha]))
            {
                mysql_format(mysql, query, sizeof(query), "SELECT * FROM `contas` WHERE `Nome` = '%e' LIMIT 1", playername);
                mysql_tquery(mysql, query, "CarregarConta", "i", playerid);
            }
            else
            {
                ShowPlayerDialog(playerid, DialogoLogin, DIALOG_STYLE_PASSWORD, "Carga Pesada Brasil - LOGIN", "{FFFFFF}Bem-vindo ao {FFFF00}Carga Pesada Brasil{FFFFFF}.\n\n{FF0000} Sua senha está incorreta.\n{FFFFFF}Se você não é o dono desta conta clique em sair pois você não está autorizado à entrar nela.", "Entrar", "Sair");
    		}
        }
        case DialogoRegistro:
        {
            if(!response) return Kick(playerid);
            if(strlen(inputtext) < 6)
            {
                SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Sua senha precisa ter mais que 5 caracteres.");
                return ShowPlayerDialog(playerid, DialogoRegistro, DIALOG_STYLE_INPUT,"Carga Pesada Brasil - REGISTRAR","{FFFFFF}Bem vindo ao {FFFF00}Carga Pesada Brasil.\n\n{FFFFFF}Você precisa registrar sua conta para poder jogar conosco.\n\n{FF0000}Não revele sua senha para nenhuma pessoa{FFFFFF}, não nos responsabilizamos por contas hackeadas!\n\nDigite uma senha para poder registrar sua conta no nosso banco de dados.\n\nDivirta-se!","Registrar","Sair");
            }
            new
                query[512],
                playername[MAX_PLAYER_NAME];


            GetPlayerName(playerid, playername, sizeof(playername));
            WP_Hash(PlayerInfo[playerid][pSenha], 129, inputtext);
            mysql_format(mysql, query, sizeof(query), "INSERT INTO `contas` (`Nome`, `Senha`, `AdminLevel`, `Dinheiro`, `Pontos`, `MsgBoasVindas`) VALUES ('%e', '%e', 0, 0, 0, 0)", playername, PlayerInfo[playerid][pSenha]);
            mysql_tquery(mysql, query, "RegistrarConta", "i", playerid);
        }
        case DialogoCaminhaoCarga: Dialogo_CaminhaoCarga(playerid, response, listitem);
        case DialogoCaminhaoCarregamento: Dialogo_CaminhaoCarregamento(playerid, response, listitem);
        case DialogoCaminhaoDescarregamento: Dialogo_CaminhaoDescarregamento(playerid, response, listitem);
    }
    return 1;
}

CMD:teleporte(playerid, params[])
{
	SetPlayerPos(playerid, -699.1899,-7450.6929,37.9266);
	return 1;
}

CMD:t(playerid, params[])
{
	new var0 = 0;
	var0 = GetPlayerVehicleID(playerid);
	DetachTrailerFromVehicle(var0);
	return 1;
}

CMD:girar(playerid, params[])
{
	new Float:var0 = 0.0, Float:var1 = 0.0, Float:var2 = 0.0;
	if(IsPlayerInAnyVehicle(playerid))
	{
		SetCameraBehindPlayer(playerid);
	}
	GetPlayerPos(playerid, var0, var1, var2);
	SetVehiclePos(GetPlayerVehicleID(playerid), var0, var1, var2);
	SetVehicleZAngle(GetPlayerVehicleID(playerid), 0.0);
	return 1;
}

CMD:pm(playerid, params[])
{
	new OutroPlayer, Mensagem[128], Msg[128], Msg2[128], NomedoJogador[24], NomedoOutroPlayer[24];
	
	if(PlayerInfo[playerid][pLogado] == true)
	{
		if (sscanf(params, "us", OutroPlayer, Mensagem)) SendClientMessage(playerid, COR_CINZA, "[USO] /pm [id/nome] [mensagem]");
		else
		{
		    if (IsPlayerConnected(OutroPlayer))
			{
		    	GetPlayerName(playerid, NomedoJogador, sizeof(NomedoJogador));
				GetPlayerName(OutroPlayer, NomedoOutroPlayer, sizeof(NomedoOutroPlayer));
				format(Msg, 128, "PM enviada para %s: %s", NomedoOutroPlayer, Mensagem);
				format(Msg2, 128, "PM recebida de %s: %s", NomedoJogador, Mensagem);
				SendClientMessage(playerid, COR_AMARELO, Msg);
				SendClientMessage(OutroPlayer, COR_AMARELO, Msg2);
			}
			else
				SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Jogador não está online!");
		}
	}
	else
	    return 0;
	    
	return 1;
}

CMD:mudar(playerid, params[])
{
	ForceClassSelection(playerid);
	SetPlayerHealth(playerid, 0.0);
	return 1;
}

CMD:comandos(playerid, params[])
{
	new string[sizeof(TabelaCmds)*128];
	format(string,1024,"{FFFFFF}Comando = Função", GetPlayerScore(playerid));
	for(new i=1; i <sizeof(TabelaCmds); i ++)
	format(string,sizeof(string),"%s\n %s",string,TabelaCmds[i]);
	ShowPlayerDialog(playerid, 93, DIALOG_STYLE_MSGBOX,"\tTabela de comandos", string, "OK", "");
	return 1;
}

CMD:pontos(playerid, params[])
{
	new string[sizeof(Pontos)*128];
	format(string,1024,"{00BFFF}Você tem {FFFF00}%d {00BFFF}pontos.", PlayerInfo[playerid][pPontos]);
	for(new i=1; i <sizeof(Pontos); i ++)
	format(string,sizeof(string),"%s\n %s",string,Pontos[i]);
	ShowPlayerDialog(playerid, 94, DIALOG_STYLE_MSGBOX,"\tTabela de Pontos", string, "OK", "");
	return 1;
}

CMD:trabalhar(playerid, params[])
{
	if(PlayerInfo[playerid][pLogado] == false)
	    return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você precisa estar logado para poder trabalhar.");

	if(PlayerInfo[playerid][pTrabalhando] == true)
	    return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você já está trabalhando.");

	switch (PlayerInfo[playerid][pClasse])
	{
	    case Caminhoneiro:
	    {
	        if(GetPlayerVehicleSeat(playerid) != 0)
	        return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você precisa ser o motorista para começar a trabalhar.");
	        
	        new ListadeProdutos[50], NumProducts, TotalLoadList[1000];
	        switch (GetVehicleModel(GetPlayerVehicleID(playerid)))
			{
				case VeiculoRoadTrain, VeiculoLineRunner, VeiculoTanker:
				{
					switch (GetVehicleModel(GetVehicleTrailer(GetPlayerVehicleID(playerid))))
					{
						case TrailerFechado1, TrailerFechado2:
							ListadeProdutos = Product_GetList(CaminhaoFechado, NumProducts);
						case TrailerMinerio:
						    ListadeProdutos = Product_GetList(CaminhaoMinerio, NumProducts);
						case TrailerFluidos:
						    ListadeProdutos = Product_GetList(CaminhaoFluido, NumProducts);
						case 0:
						    SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você precisa de um trailer para continuar!");
					}
				}
				case 440:
				    ListadeProdutos = Product_GetList(CaminhaoFechado, NumProducts);
			}

			for (new i; i < NumProducts; i++)
			format(TotalLoadList, 1000, "%s%s\n", TotalLoadList, ACarga[ListadeProdutos[i]][LoadName]);
 			ShowPlayerDialog(playerid, DialogoCaminhaoCarga, DIALOG_STYLE_LIST, "Selecione sua carga:", TotalLoadList, "Selecionar", "Sair");
		}
	}
	return 1;
}

CMD:gmr(playerid, params[])
{
	if(PlayerInfo[playerid][pAdmin] != 5)
	    return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você não tem permissão pra usar este comando.");

 	GameModeExit();
	return 1;
}

CMD:daradmin(playerid, params[])
{
	if(PlayerInfo[playerid][pAdmin] < 5 && !IsPlayerAdmin(playerid))
		return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você não tem permissão para usar este comando.");

 	new tmp[24], index; tmp = strtok(params, index);
	if(!strlen(tmp))
		return SendClientMessage(playerid, COR_CINZA, "[USO] /daradmin [id/nick] [level(1-5)]");

	new level;
	new giveid = ReturnUser(tmp);
	tmp = strtok(params, index);
	level = strval(tmp);
	if(level < 0 || level > 5)
        return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Level somente de 0 à 5.");

	PlayerInfo[giveid][pAdmin] = level;
	new playername[24];
	new string[128];
	GetPlayerName(playerid,playername,sizeof(playername));
	if(level == 1)
	{
        format(string, sizeof(string), "Você foi setado Ajudante, level 1, pelo %s %s.", CargoAdmin(playerid), playername);
		SendClientMessage(giveid, COR_ROSA, string);
		SendClientMessage(giveid, COR_AZUL, "Parabéns, você foi setado pelo primeiro level de administrador do {FF0000}Carga Pesada Brasil{00BFFF}!");
		SendClientMessage(giveid, COR_AZUL, "Esperamos que você tenha uma ótima estadia como parte da administração do nosso servidor.");
		SendClientMessage(giveid, COR_AZUL, "Leia as {FF0000}/regrasadmin {00BFFF}para ficar dentro das regras daadministração do CPB.");
		SendClientMessage(giveid, COR_AZUL, "Digite {FF0000}/acmds {00BFFF}para saber os comandos do seu atual cargo de administrador.");
		return 1;
	}
	if(level == 0)
	{
	    format(string, sizeof(string), "O %s %s te expulsou da Equipe da Administração do Carga Pesada Brasil.", CargoAdmin(playerid), playername);
	    SendClientMessage(giveid, COR_VERMELHO, string);
	    SendClientMessage(giveid, COR_VERMELHO, "Seu level foi setado para 0.");
	    SendClientMessage(giveid, COR_AZUL, "Agradescemos sua compania. Bom jogo!");
		return 1;
	}
	format(string, sizeof(string), "Você foi setado %s, level %d, pelo %s %s.", CargoAdmin(giveid), level, CargoAdmin(playerid), playername);
	SendClientMessage(giveid, COR_AZUL, string);
	return 1;
}

CMD:regrasadmin(playerid, params[])
{
	if(PlayerInfo[playerid][pAdmin] == 0)
	    return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você não tem permissão para usar esse comando.");

	new string[sizeof(RegrasAdmin)*128];
	for(new i=1; i <sizeof(RegrasAdmin); i ++)
	format(string,sizeof(string),"%s\n %s",string,RegrasAdmin[i]);
	ShowPlayerDialog(playerid, 95, DIALOG_STYLE_MSGBOX,"\tRegras de Administração", string, "OK", "");
	return 1;

}

CMD:spawncarro(playerid, params[])
{
	if(PlayerInfo[playerid][pAdmin] == 0)
		return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você não tem permissão para usar este comando.");

	if(!IsPlayerInAnyVehicle(playerid))
	    return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você precisa estar em um veículo para spawna-lo.");

    SetVehicleToRespawn(GetPlayerVehicleID(playerid));
	RemovePlayerFromVehicle(playerid);
    SendClientMessage(playerid, COR_AMARELO, "Veiculo resetado!");
	return 1;
}

CMD:acmds(playerid, params[])
{
	if(PlayerInfo[playerid][pAdmin] == 0)
	    return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você não tem permissão pra usar esse comando.");

	new string[sizeof(AdminCmds)*128];
	for(new i=1; i <sizeof(AdminCmds); i ++)
	format(string,sizeof(string),"%s\n %s",string,AdminCmds[i]);
	ShowPlayerDialog(playerid, 95, DIALOG_STYLE_MSGBOX,"\tComandos da Administração", string, "OK", "");
	return 1;
}

CMD:admins(playerid, params[])
{
	new string[128], count = 0;
	SendClientMessage(playerid, COR_AMARELO, "Carga Pesada Brasil - ADMINISTRADORES");
	for(new i = 0; i <= MAX_PLAYERS; i++)
	{
		if(IsPlayerConnected(i))
		{
		    if(PlayerInfo[i][pAdmin] > 0 && PlayerInfo[i][pAdmin] < 6)
		    {
		        format(string,sizeof(string),"{00BFFF}%s{FFFF00} | Cargo: %s | ID: %d \n", NomedoPlayer(i), CargoAdmin(i), i);
	        	SendClientMessage(playerid, COR_AMARELO, string);
	        	count++;
			}
		}
	}
	if(count == 0)
	{
 		SendClientMessage(playerid, COR_VERMELHO, "Nenhum administrador online!");
	}
	return 1;
}

CMD:ip(playerid, params[])
{
	if(PlayerInfo[playerid][pAdmin] < 1)
        return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você não tem permissão para usar este comando!");

	new tmp[24], idx;
	tmp = strtok(params,idx);
	new playersip[256];
	if(!strlen(tmp))
	return SendClientMessage(playerid,COR_CINZA,"USE: /ip [id/nick]");

	new string[128];
	new giveid = ReturnUser(tmp);
	GetPlayerIp(giveid,playersip,sizeof(playersip));
	format(string, sizeof(string), "{00BFFF}%s{FFFF00} (id:%i) | IP: %s",NomedoPlayer(giveid), giveid ,playersip);
	SendClientMessage(playerid,COR_AMARELO,string);
	return 1;
}

CMD:an(playerid, params[])
{
	new string[128], texto[128];
	if (sscanf(params, "s", texto)) SendClientMessage(playerid, COR_CINZA, "[USO] /an [texto]");
	else
	{
		if (PlayerInfo[playerid][pAdmin] > 0)
		{
			format(string, 128, "[%s] %s: %s", CargoAdmin(playerid), NomedoPlayer(playerid), texto);
	   		SendClientMessageToAll(COR_ROSACLARO, string);
   		}
	}
	return 1;
}

CMD:spec(playerid, params[])
{
	if(PlayerInfo[playerid][pAdmin] > 0)
	{
	    new tmp[24], idx;
		tmp = strtok(params, idx);

		if(!strlen(tmp))
			return SendClientMessage(playerid, COR_CINZA, "[USO] /spec [id/off]");
        if(strcmp(tmp, "off", true)==0)
		{
	 		if(GetPlayerState(playerid) == PLAYER_STATE_SPECTATING )
	 		{
   				StopSpectate(playerid);
				return 1;
			}
			else
  				return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você não está espectando ninguém.");
		}
		new giveid = ReturnUser(tmp);
  		if(!IsPlayerConnected(giveid))
	   		return SendClientMessage(playerid, COR_VERMELHO,"[ERRO] Jogador não conectado");
		else if(giveid == playerid)
			return SendClientMessage(playerid, COR_VERMELHO,"[ERRO] Não é possível se espiar.");
		else if(PlayerInfo[giveid][pAdmin] >= 5)
			return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você não pode dar spec nos Fundadores.");
		else if(GetPlayerState(giveid) == PLAYER_STATE_SPECTATING)
			return	SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Jogador escolhido já está espectando alguém.");
		else if(GetPlayerState(giveid) != 1 && GetPlayerState(giveid) != 2 && GetPlayerState(giveid) != 3)
	 		return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] O jogador não está jogando.");
		if(GetPlayerState(playerid) != PLAYER_STATE_SPECTATING)
		{
			SendClientMessage(playerid, COR_VERMELHO, "[SPEC] Você está espiando um jogador. Para sair digite /spec off.");
			StartSpectate(playerid, giveid);
		}
	}
	return 1;
}

CMD:reportar(playerid, params[])
{
	new tmp[256],Index; tmp = strtok(params,Index);
	if(!strlen(params) || !strlen(params[strlen(tmp)+1]) || strlen(params[strlen(tmp)+1]) > 24)
		return SendClientMessage(playerid, COR_CINZA,"[USO] Uso: /reportar [id] [motivo]");

	new id;
  	if(!IsNumeric(tmp))
		id = ReturnUser(tmp);
	else
		id = strval(tmp);

	if(!IsPlayerConnected(id) || id == playerid)
		return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Jogador não está online!");
	else
	{
	    new string[128];
	   	AdminChat(COR_VERMELHO," ");
		format(string, 128,"[REPORT] Denúncia de %s (id: %d) contra %s (id: %d) | %s",NomedoPlayer(playerid),playerid,NomedoPlayer(id),id,params[strlen(tmp)+1]);
		AdminChat(COR_AZUL,string);

		format(string, 128, "~n~~n~~n~~w~Denuncia de %s(%d) ~n~~p~contra %s(%d)~n~~r~Motivo: %s",NomedoPlayer(playerid),playerid,NomedoPlayer(id),id,params[strlen(tmp)+1]);

		for(new i = 0; i < MAX_PLAYERS+1; i++)
		{
			if(IsPlayerConnected(i) && PlayerInfo[i][pAdmin] > 0)
			{
   				PlaySoundForPlayer(i,1147);
				GameTextForPlayer(i,string,5000,5);
			}
		}
		SendClientMessage(playerid,COR_AMARELO,"Denúncia enviada. Nossos administradores estarão de olho no player. Obrigado por reportar!");

	}
	return 1;
}

stock ReturnUser(PlayerName[])
{
	if(IsNumeric(PlayerName))
	    return strval(PlayerName);
	else
	{
		new found=0, id;
		for(new i=0; i <= MAX_PLAYERS; i++)
		{
			if(IsPlayerConnected(i))
			{
		  		new foundname[MAX_PLAYER_NAME];
		  		GetPlayerName(i, foundname, MAX_PLAYER_NAME);
				new namelen = strlen(foundname);
				new bool:searched=false;
		    	for(new pos=0; pos <= namelen; pos++)
				{
					if(searched != true)
					{
						if(strfind(foundname,PlayerName,true) == pos)
						{
			                found++;
							id = i;
						}
					}
				}
			}
		}
		if(found == 1)
			return id;
		else
			return INVALID_PLAYER_ID;
	}
}
public Velocidade()
{
	for(new i = 0; i < MAX_PLAYERS; i++)
	{
    	if(IsPlayerConnected(i))
        {
            if(IsPlayerInAnyVehicle(i))
            {
				new vehicleid,Float:speed_x,Float:speed_y,Float:speed_z,Float:final_speed,speed_string[256],final_speed_int;
				vehicleid = GetPlayerVehicleID(i);
				if(vehicleid != 0)
				{
					GetVehicleVelocity(vehicleid,speed_x,speed_y,speed_z);
					final_speed = floatsqroot(((speed_x*speed_x)+(speed_y*speed_y))+(speed_z*speed_z))*136.666667;
					final_speed_int = floatround(final_speed,floatround_round);
	    			format(speed_string,256,"Velocidade: ~g~%i~w~ km/h~n~~n~~n~",final_speed_int);
					TextDrawSetString(Velocimetro, speed_string);
				}
				else
				{
					TextDrawSetString(Velocimetro, " ");
    			}

			}
		}
	}
	return 1;
}

strtok(const string[], &index)
{
	new length = strlen(string);
	while ((index < length) && (string[index] <= ' '))
	{
		index++;
	}

	new offset = index;
	new result[20];
	while ((index < length) && (string[index] > ' ') && ((index - offset) < (sizeof(result) - 1)))
	{
		result[index - offset] = string[index];
		index++;
	}
	result[index - offset] = EOS;
	return result;
}

stock CargoAdmin(i)
{
	new admtext[64];
    if(PlayerInfo[i][pAdmin] == 5)
		admtext = "Fundador";
    else if(PlayerInfo[i][pAdmin] == 4)
		admtext = "Organizador";
  	else if(PlayerInfo[i][pAdmin] == 3)
	  	admtext = "Supervisor";
    else if(PlayerInfo[i][pAdmin] == 2)
		admtext = "Moderador";
	else if(PlayerInfo[i][pAdmin] == 1)
		admtext = "Ajudante";
	return admtext;
}

stock StartSpectate(playerid, specid)
{
	for(new xb=0; xb<MAX_PLAYERS; xb++)
	{
 		if(GetPlayerState(xb) == PLAYER_STATE_SPECTATING && PlayerInfo[xb][gSpectateID] == playerid)
		{
  			AdvanceSpectate(xb);
   		}
    }
	if(IsPlayerInAnyVehicle(specid))
	{
		SetPlayerInterior(playerid,GetPlayerInterior(specid));
        TogglePlayerSpectating(playerid, 1);
        PlayerSpectateVehicle(playerid, GetPlayerVehicleID(specid));
        PlayerInfo[playerid][gSpectateID] = specid;
        PlayerInfo[playerid][gSpectateType] = ADMIN_SPEC_TYPE_VEHICLE;
    }
	else
	{
        SetPlayerInterior(playerid,GetPlayerInterior(specid));
        TogglePlayerSpectating(playerid, 1);
        PlayerSpectatePlayer(playerid, specid);
        PlayerInfo[playerid][gSpectateID] = specid;
		PlayerInfo[playerid][gSpectateType] = ADMIN_SPEC_TYPE_PLAYER;
    }

    SetPlayerVirtualWorld(playerid,GetPlayerVirtualWorld(specid));

    new string[128];
    format(string,sizeof(string),"~n~~n~~n~~n~~n~~n~~n~~n~~n~~r~%s - ID:%d~n~~y~~h~< Shift ~w~-~b~~h~ Space >", NomedoPlayer(specid),specid);
	GameTextForPlayer(playerid,string,10000,3);
    return 1;
}

stock StopSpectate(playerid)
{
    TogglePlayerSpectating(playerid, 0);
   	PlayerInfo[playerid][gSpectateID] = INVALID_PLAYER_ID;
   	PlayerInfo[playerid][gSpectateType] = ADMIN_SPEC_TYPE_NONE;
    GameTextForPlayer(playerid,"~n~~n~~n~~n~~n~~n~~n~~n~~r~Spectate Desligado",1000,3);
    return 1;
}

stock AdvanceSpectate(playerid)
{
    if(ConnectedPlayers() == 2) { StopSpectate(playerid); return 1; }
	if(GetPlayerState(playerid) == PLAYER_STATE_SPECTATING && PlayerInfo[playerid][gSpectateID] != INVALID_PLAYER_ID) {
            for(new xb=PlayerInfo[playerid][gSpectateID]+1; xb<=MAX_PLAYERS; xb++) {
                if(xb == MAX_PLAYERS) { xb = 0; }
                if(IsPlayerConnected(xb) && xb != playerid) {
                                if(GetPlayerState(xb) == PLAYER_STATE_SPECTATING && PlayerInfo[xb][gSpectateID] != INVALID_PLAYER_ID ||
                                        (GetPlayerState(xb) != 1 && GetPlayerState(xb) != 2 && GetPlayerState(xb) != 3))
                                {
                                        continue;
                                }
                                else {
                                        StartSpectate(playerid, xb);
                                        break;
                                }
                        }
                }
        }
 	return 1;
}

stock ConnectedPlayers()
{
        new count;
        for(new xb=0; xb<MAX_PLAYERS; xb++) {
            if(IsPlayerConnected(xb)) {
                        count++;
                }
        }
        return count;
}

NomedoPlayer(playerid)
{
	new p_name[MAX_PLAYER_NAME];
	GetPlayerName(playerid,p_name,sizeof(p_name));
	return p_name;
}

forward AdminChat(color,const string[]);
public AdminChat(color,const string[])
{
	for(new i = 0; i <= MAX_PLAYERS; i++)
	{
		if(IsPlayerConnected(i))
		{
			if(PlayerInfo[i][pAdmin] > 0)
			{
				SendClientMessage(i, color, string);
			}
		}
	}
	return 1;
}

stock PlaySoundForPlayer(playerid, soundid)
{
	new Float:pX, Float:pY, Float:pZ;
	GetPlayerPos(playerid, pX, pY, pZ);
	PlayerPlaySound(playerid, soundid,pX, pY, pZ);
}

stock IsNumeric(const string[])
{
	for (new i = 0, j = strlen(string); i < j; i++)
	    if(string[i] > '9' || string[i] < '0') return 0;

	return 1;
}

forward ChecarVidadoCarro();
public ChecarVidadoCarro()
{
	for(new car = 1; car <= MAX_VEHICLES; car++)
	{
	    new Float:health;
    	GetVehicleHealth(car, health);
    	if(health < 300)
    	{
    	    SetVehicleParamsEx(car,VEHICLE_PARAMS_OFF,0,0,0,VEHICLE_PARAMS_ON,0,0);
    		SetVehicleHealth(car,250);
		}
	}
	return 1;
}

public Mensagens()
{
	new string[128];
	new random1 = random(sizeof(mensagens));
	format(string, sizeof(string), "%s", mensagens[random1]);
	SendClientMessageToAll(COR_AMARELO,string);
	return 1;
}

forward ChecarConta(playerid);
public ChecarConta(playerid)
{
    new
        rows,
        fields;
    cache_get_data(rows, fields, mysql);

    if(rows)
    {
        cache_get_field_content(0, "Senha", PlayerInfo[playerid][pSenha], mysql, 129);
        PlayerInfo[playerid][pID] = cache_get_field_content_int(0, "ID");
        ShowPlayerDialog(playerid, DialogoLogin, DIALOG_STYLE_PASSWORD, "Carga Pesada Brasil - LOGIN", "{FFFFFF}Bem-vindo ao {FFFF00}Carga Pesada Brasil{FFFFFF}.\n\nVocê tem uma conta em nosso banco de dados, por favor, digite sua senha para logar.\n\nDivirta-se!", "Entrar", "Sair");
    }
    else
    {
        ShowPlayerDialog(playerid, DialogoRegistro, DIALOG_STYLE_INPUT,"Carga Pesada Brasil - REGISTRAR","{FFFFFF}Bem vindo ao {FFFF00}Carga Pesada Brasil{FFFFFF}.\n\nVocê precisa registrar sua conta para poder jogar conosco.\n\n{FF0000}Não revele sua senha para nenhuma pessoa{FFFFFF}, não nos responsabilizamos por contas hackeadas!\n\nDigite uma senha para poder registrar sua conta no nosso banco de dados.\n\nDivirta-se!","Registrar","Sair");
    }
    return true;
}

forward CarregarConta(playerid);
public CarregarConta(playerid)
{
    PlayerInfo[playerid][pAdmin] = cache_get_field_content_int(0, "AdminLevel");
    PlayerInfo[playerid][pIP] = cache_get_field_content_int(0, "IP");
    PlayerInfo[playerid][pDinheiro] = cache_get_field_content_int(0, "Dinheiro");
    PlayerInfo[playerid][MsgBoasVindas] = cache_get_field_content_int(0, "MsgBoasVindas");
	PlayerInfo[playerid][pPontos] = cache_get_field_content_int(0, "Pontos");
    TogglePlayerSpectating(playerid, false);
	SetPlayerScore(playerid, PlayerInfo[playerid][pPontos]);
    GivePlayerMoney(playerid, PlayerInfo[playerid][pDinheiro]);
    PlayerInfo[playerid][pLogado] = true;
    SpawnPlayer(playerid);
    SendClientMessage(playerid, -1, "Você está logado no Carga Pesada Brasil.");
    return true;
}

forward RegistrarConta(playerid);
public RegistrarConta(playerid)
{
	new playername[MAX_PLAYER_NAME];
	GetPlayerName(playerid, playername, sizeof(playername));
    PlayerInfo[playerid][pID] = cache_insert_id();
    printf("[Carga Pesada Brasil] Nova conta registrada. Nome: %s. ID: %d.", playername, PlayerInfo[playerid][pID]);
    SendClientMessage(playerid, -1, "Conta registrada com sucesso no banco de dados MySQL.");
    PlayerInfo[playerid][pDinheiro] = 5000;
    PlayerInfo[playerid][pPontos] = 0;
    PlayerInfo[playerid][pAdmin] = 0;
    PlayerInfo[playerid][MsgBoasVindas] = 0;
    TogglePlayerSpectating(playerid, false);
    PlayerInfo[playerid][pLogado] = true;
	SpawnPlayer(playerid);
    return true;
}

Dialogo_CaminhaoCarga(playerid, response, listitem)
{
	new TotalStartLocList[1000], ProductList[50], NumProducts, ProductID, LocID;
	if(!response) return 1;
	switch (GetVehicleModel(GetPlayerVehicleID(playerid))) 
	{
		case VeiculoRoadTrain, VeiculoLineRunner, VeiculoTanker:
		{
			switch (GetVehicleModel(GetVehicleTrailer(GetPlayerVehicleID(playerid))))
			{
				case TrailerFechado1, TrailerFechado2:
					ProductList = Product_GetList(CaminhaoFechado, NumProducts);
				case TrailerMinerio:
					ProductList = Product_GetList(CaminhaoMinerio, NumProducts);
				case TrailerFluidos:
				    ProductList = Product_GetList(CaminhaoFluido, NumProducts);
			}
		}
		case 440:
		    ProductList = Product_GetList(CaminhaoFechado, NumProducts);
	}
	PlayerInfo[playerid][CargaID] = ProductList[listitem];
	ProductID = PlayerInfo[playerid][CargaID];
	for (new i; i < 30; i++)
	{
	    LocID = ACarga[ProductID][FromLocations][i];
	    if (LocID != 0)
			format(TotalStartLocList, 1000, "%s%s\n", TotalStartLocList, LocalCargaDescarga[LocID][NomedoLocal]); // Add the location-name to the list
		else
		    break;
	}
	ShowPlayerDialog(playerid, DialogoCaminhaoCarregamento, DIALOG_STYLE_LIST, "Selecione o local de carregamento", TotalStartLocList, "Selecionar", "Cancelar");
	return 1;
}

Dialogo_CaminhaoCarregamento(playerid, response, listitem)
{
	new ProductID, LocID, TotalEndLocList[1000];
	if(!response) return 1;
	ProductID = PlayerInfo[playerid][CargaID];
	PlayerInfo[playerid][Carregamento] = ACarga[ProductID][FromLocations][listitem];
	for (new i; i < 30; i++)
	{
	    LocID = ACarga[ProductID][ToLocations][i];
	    if (LocID != 0)
			format(TotalEndLocList, 1000, "%s%s\n", TotalEndLocList, LocalCargaDescarga[LocID][NomedoLocal]);
		else
		    break;
	}
	ShowPlayerDialog(playerid, DialogoCaminhaoDescarregamento, DIALOG_STYLE_LIST, "Selecione o local de descarregamento", TotalEndLocList, "Selecionar", "Cancelar");
	return 1;
}

Dialogo_CaminhaoDescarregamento(playerid, response, listitem)
{
	new loadName[50], startlocName[50], endlocName[50], LoadMsg[128], Float:x3, Float:y3, Float:z3, ProductID;
	if(!response) return 1;
	ProductID = PlayerInfo[playerid][CargaID];
	PlayerInfo[playerid][Descarregamento] = ACarga[ProductID][ToLocations][listitem];
	format(loadName, 50, "%s", ACarga[ProductID][LoadName]);
	format(startlocName, 50, "%s", LocalCargaDescarga[PlayerInfo[playerid][Carregamento]][NomedoLocal]);
	format(endlocName, 50, "%s", LocalCargaDescarga[PlayerInfo[playerid][Descarregamento]][NomedoLocal]);
	PlayerInfo[playerid][pTrabalhando] = true;
	PlayerInfo[playerid][VeiculoID] = GetPlayerVehicleID(playerid);
	PlayerInfo[playerid][TrailerID] = GetVehicleTrailer(GetPlayerVehicleID(playerid));
	PlayerInfo[playerid][PartedoTrabalho] = 1;
	x3 = LocalCargaDescarga[PlayerInfo[playerid][Carregamento]][LocX];
	y3 = LocalCargaDescarga[PlayerInfo[playerid][Carregamento]][LocY];
	z3 = LocalCargaDescarga[PlayerInfo[playerid][Carregamento]][LocZ];
	SetPlayerCheckpoint(playerid, x3, y3, z3, 7);
	format(LoadMsg, 128, "Você está carregando %s de %s para %s", loadName, startlocName, endlocName);
	SendClientMessage(playerid, 0xFFFFFFFF, LoadMsg);

	return 1;
}

Caminhoneiro_EntrouCP(playerid)
{
	if (GetPlayerVehicleID(playerid) != PlayerInfo[playerid][VeiculoID])
	    return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você precisa estar em um caminhão para carregar seu trailer!");
	if (PlayerInfo[playerid][TrailerID] != GetVehicleTrailer(GetPlayerVehicleID(playerid)))
		return SendClientMessage(playerid, COR_VERMELHO, "[ERRO] Você precisa de um trailer para continuar o trabalho!");

    switch (PlayerInfo[playerid][PartedoTrabalho])
    {
		case 1:
			SendClientMessage(playerid, COR_AMARELO, "Carregando seu caminhão, por favor, aguarde!");
		case 2:
		    SendClientMessage(playerid, COR_AMARELO, "Descarregando seu caminhão, por favor, aguarde!");
	}
	TogglePlayerControllable(playerid, 0);
	PlayerInfo[playerid][TempoCargaDescarga] = SetTimerEx("Caminhoneiro_CarregarDesc", 5000, false, "d" , playerid);
	return 1;
}

forward Caminhoneiro_CarregarDesc(playerid);
public Caminhoneiro_CarregarDesc(playerid)
{
	switch (PlayerInfo[playerid][PartedoTrabalho])
	{
	    case 1: //Quando o player vai pegar a carga
		{
			new StartLoc[50], EndLoc[50], Load[50], Float:x, Float:y, Float:z, UnloadMsg[100];
			PlayerInfo[playerid][PartedoTrabalho] = 2;
			DisablePlayerCheckpoint(playerid);
			format(StartLoc, 50, LocalCargaDescarga[PlayerInfo[playerid][Carregamento]][NomedoLocal]);
			format(EndLoc, 50, LocalCargaDescarga[PlayerInfo[playerid][Descarregamento]][NomedoLocal]);
			format(Load, 50, ACarga[PlayerInfo[playerid][CargaID]][LoadName]);
			x = LocalCargaDescarga[PlayerInfo[playerid][Descarregamento]][LocX];
			y = LocalCargaDescarga[PlayerInfo[playerid][Descarregamento]][LocY];
			z = LocalCargaDescarga[PlayerInfo[playerid][Descarregamento]][LocZ];
			SetPlayerCheckpoint(playerid, x, y, z, 7);
			TogglePlayerControllable(playerid, 1);
			format(UnloadMsg, 100, "Leve a carga de %s até %s.", Load, EndLoc);
			SendClientMessage(playerid, 0xFFFFFFFF, UnloadMsg);
		}
		case 2: //Quando o player vai entregar a carga
		{
			new StartLoc[50], EndLoc[50], Load[50], Msg1[128], Name[24];
			GetPlayerName(playerid, Name, sizeof(Name));
			format(StartLoc, 50, LocalCargaDescarga[PlayerInfo[playerid][Carregamento]][NomedoLocal]);
			format(EndLoc, 50, LocalCargaDescarga[PlayerInfo[playerid][Descarregamento]][NomedoLocal]);
			format(Load, 50, ACarga[PlayerInfo[playerid][CargaID]][LoadName]);
			format(Msg1, 128, "Caminhoneiro %s entregou %s de %s para %s.", Name, Load, StartLoc, EndLoc);
			SendClientMessageToAll(0xFFFFFFFF, Msg1);
			new Float:x1, Float:y1, Float:x2, Float:y2, Float:Distance, Message[128], Payment;
			x1 = LocalCargaDescarga[PlayerInfo[playerid][Carregamento]][LocX];
			y1 = LocalCargaDescarga[PlayerInfo[playerid][Carregamento]][LocY];
			x2 = LocalCargaDescarga[PlayerInfo[playerid][Descarregamento]][LocX];
			y2 = LocalCargaDescarga[PlayerInfo[playerid][Descarregamento]][LocY];
			Distance = floatsqroot(((x2 - x1) * (x2 - x1)) + ((y2 - y1) * (y2 - y1)));
			Payment = floatround((Distance * ACarga[PlayerInfo[playerid][CargaID]][PayPerUnit]), floatround_floor);
			RewardPlayer(playerid, Payment, 0);
			format(Message, 128, "Você finalizou a entrega e ganhou R$%i.", Payment);
			SendClientMessage(playerid, 0xFFFFFFFF, Message);
			TogglePlayerControllable(playerid, 1);
			if (Distance > 3000.0)
				RewardPlayer(playerid, 0, 2);
			else
				RewardPlayer(playerid, 0, 1);
			Caminhoneiro_AcabouTrabalho(playerid);
		}
	}
	return 1;
}
RewardPlayer(playerid, dinheiro, pontos)
{
	PlayerInfo[playerid][pDinheiro] = PlayerInfo[playerid][pDinheiro] + dinheiro;
	PlayerInfo[playerid][pPontos] = PlayerInfo[playerid][pPontos] + pontos;
	GivePlayerMoney(playerid, dinheiro);
	SetPlayerScore(playerid, PlayerInfo[playerid][pPontos]);
}

Caminhoneiro_AcabouTrabalho(playerid)
{
	if (PlayerInfo[playerid][pTrabalhando] == true)
	{
		PlayerInfo[playerid][pTrabalhando] = false;
		PlayerInfo[playerid][PartedoTrabalho] = 0;
		PlayerInfo[playerid][VeiculoID] = 0;
		PlayerInfo[playerid][TrailerID] = 0;
		PlayerInfo[playerid][CargaID] = 0;
		PlayerInfo[playerid][Carregamento] = 0;
		PlayerInfo[playerid][Descarregamento] = 0;
		DisablePlayerCheckpoint(playerid);
		KillTimer(PlayerInfo[playerid][TempoCargaDescarga]);
	}

	return 1;
}
